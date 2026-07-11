package persistence

import (
	"context"
	"sort"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/person"
	"github.com/jmoiron/sqlx"
)

type PersonsRepository struct {
	DB     *sqlx.DB
	Crypto application.Encryptor
}

func NewPersonsRepository(db *sqlx.DB, crypto application.Encryptor) person.Repository {
	return &PersonsRepository{
		DB:     db,
		Crypto: crypto,
	}
}

func (r *PersonsRepository) FindById(ctx context.Context, idPerson uint) (*person.Person, error) {
	var person person.Person
	err := r.DB.GetContext(ctx, &person, "SELECT id, firstname, lastname FROM Persons WHERE id = ?", idPerson)
	if err != nil {
		return nil, err
	}
	return &person, nil
}

func (r *PersonsRepository) FindPersonsWithTagsAndCategories(ctx context.Context, idUser uint64) (map[uint]person.Person, map[uint][]person.Nickname, error) {
	results, err := r.DB.QueryxContext(ctx, `
		SELECT Persons.id, firstname, lastname, Tags.id as idTag, tag
		FROM Persons
		INNER JOIN Tags
		INNER JOIN Categories
		ON Persons.id = Tags.idPerson
		AND Categories.id = Tags.idCategory
		WHERE Categories.idUser = ?
		ORDER BY Persons.id, Tags.id
	`, idUser)
	if err != nil {
		return nil, nil, err
	}
	defer results.Close()

	nicknames := make(map[uint][]person.Nickname)
	persons := make(map[uint]person.Person)
	for results.Next() {
		var nickname person.Nickname
		var p person.Person
		err = results.Scan(&p.Id, &p.Firstname, &p.Lastname, &nickname.Id, &nickname.Nickname)
		if err != nil {
			return nil, nil, err
		}

		decNickname, err := r.Crypto.Decrypt(nickname.Nickname, idUser)
		if err != nil {
			return nil, nil, err
		}
		nickname = person.Nickname{Id: nickname.Id, Nickname: decNickname}
		nicknames[p.Id] = append(nicknames[p.Id], nickname)
		persons[p.Id] = p
	}
	if err := results.Err(); err != nil {
		return nil, nil, err
	}

	return persons, nicknames, nil
}

func (r *PersonsRepository) CreatePersonWithTags(ctx context.Context, encFirstname string, encLastname string, encMainTagName string, idCategoryPerson uint, nicknames []string, idUser uint64) error {
	// Insert person
	tx, err := r.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	res, err := tx.ExecContext(ctx, "INSERT INTO Persons (firstname, lastname, idCategory) VALUES (?, ?, ?)", encFirstname, encLastname, idCategoryPerson)
	if err != nil {
		return err
	}

	idPerson, err := res.LastInsertId()
	if err != nil {
		return err
	}

	// create main tag
	res, err = tx.ExecContext(ctx, "INSERT INTO Tags (tag, idCategory, idPerson) VALUES (?, ?, ?)", encMainTagName, idCategoryPerson, idPerson)
	if err != nil {
		return err
	}

	mainTagId, err := res.LastInsertId()
	if err != nil {
		return err
	}

	// create nickname tags as synonyms of the main tag
	for _, nickname := range nicknames {
		encNickname, err := r.Crypto.Encrypt(nickname, idUser)
		if err != nil {
			return err
		}
		_, err = tx.ExecContext(ctx, "INSERT INTO Tags (tag, idCategory, idPerson, idParentTag) VALUES (?, ?, ?, ?)", encNickname, idCategoryPerson, idPerson, mainTagId)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (r *PersonsRepository) CheckPersonIdsWithTagsAndCategories(ctx context.Context, idUser uint64, idPerson uint) error {
	var personIdToCheck uint
	return r.DB.GetContext(ctx, &personIdToCheck, `
		SELECT DISTINCT(Persons.id)
		FROM Persons INNER JOIN Tags INNER JOIN Categories
		ON Persons.id = Tags.idPerson
		AND Categories.id = Tags.idCategory
		WHERE Categories.idUser = ?
		AND Persons.id = ?
	`, idUser, idPerson)
}

func (r *PersonsRepository) UpdatePersonWithTags(
	ctx context.Context,
	storedPerson *person.Person,
	encFirstname string,
	encLastname string,
	encMainTagName string,
	mainPersonTagId uint,
	idCategoryPerson uint,
	idUser uint64,
	bodyNicknames []person.Nickname,
) error {
	tx, err := r.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	if encFirstname != storedPerson.Firstname || encLastname != storedPerson.Lastname {
		_, err = tx.ExecContext(ctx, "UPDATE Persons SET firstname = ?, lastname = ? WHERE id = ?", encFirstname, encLastname, storedPerson.Id)
		if err != nil {
			return err
		}

		_, err = tx.ExecContext(ctx, "UPDATE Tags SET tag = ? WHERE id = ?", encMainTagName, mainPersonTagId)
		if err != nil {
			return err
		}
	}

	// Get nicknames of the person (synonyms of the main tag)
	var nicknames []person.Nickname
	err = tx.SelectContext(ctx, &nicknames, `
		SELECT Tags.id, tag as nickname
		FROM Tags
		INNER JOIN Categories
		ON Tags.idCategory = Categories.id
		WHERE idPerson = ?
		AND idUser = ?
		AND idParentTag IS NOT NULL
		ORDER BY Tags.id`, storedPerson.Id, idUser)
	if err != nil {
		return err
	}

	// Merge the stored nicknames (n1, sorted by id) with the requested ones
	// (n2, sorted by id, new entries with id 0 first):
	//   n2.id == 0  -> INSERT
	//   n1.id < n2.id (n1 absent from the body) -> DELETE
	//   n1.id == n2.id -> UPDATE when the text changed
	// Stored ids missing from the body are deleted; body ids missing from the
	// db are ignored (they do not belong to this person).

	sort.Slice(bodyNicknames, func(i, j int) bool {
		return bodyNicknames[i].Id < bodyNicknames[j].Id
	})

	deleteNickname := func(idTag uint) error {
		// Repoint the tagged events to the "main" name of the person, dropping
		// the links whose event already references the main tag.
		_, err := tx.ExecContext(ctx, `
			DELETE FROM EventsTags
			WHERE idTag = ?
			AND idEvent IN (
				SELECT idEvent FROM (
					SELECT idEvent FROM EventsTags WHERE idTag = ?
				) AS mainEvents
			)
		`, idTag, mainPersonTagId)
		if err != nil {
			return err
		}

		_, err = tx.ExecContext(ctx, "UPDATE EventsTags SET idTag = ? WHERE idTag = ?", mainPersonTagId, idTag)
		if err != nil {
			return err
		}

		_, err = tx.ExecContext(ctx, "DELETE FROM Tags WHERE id = ?", idTag)
		return err
	}

	insertNickname := func(nickname string) error {
		encNickname, err := r.Crypto.Encrypt(nickname, idUser)
		if err != nil {
			return err
		}
		_, err = tx.ExecContext(ctx, "INSERT INTO Tags (tag, idCategory, idPerson, idParentTag) VALUES (?, ?, ?, ?)", encNickname, idCategoryPerson, storedPerson.Id, mainPersonTagId)
		return err
	}

	lastIndex := 0
	for _, n1 := range nicknames {
		matched := false
		for ; lastIndex < len(bodyNicknames); lastIndex++ {
			n2 := bodyNicknames[lastIndex]

			// Insertion of the nickname
			if n2.Id == 0 {
				if err := insertNickname(n2.Nickname); err != nil {
					return err
				}
				continue
			}

			// n1 is not part of the body anymore -> deletion
			if n1.Id < n2.Id {
				break
			}

			// Update of the nickname
			if n1.Id == n2.Id {
				encNickname, err := r.Crypto.Encrypt(n2.Nickname, idUser)
				if err != nil {
					return err
				}
				if n1.Nickname != encNickname {
					_, err = tx.ExecContext(ctx, "UPDATE Tags SET tag = ? WHERE id = ?", encNickname, n1.Id)
					if err != nil {
						return err
					}
				}
				lastIndex++
				matched = true
				break
			}

			// n1.Id > n2.Id: the body references a tag that is not a nickname
			// of this person -> ignore it (can be code injection)
		}

		if !matched {
			if err := deleteNickname(n1.Id); err != nil {
				return err
			}
		}
	}

	// Insert the remaining new nicknames
	for ; lastIndex < len(bodyNicknames); lastIndex++ {
		if bodyNicknames[lastIndex].Id == 0 {
			if err := insertNickname(bodyNicknames[lastIndex].Nickname); err != nil {
				return err
			}
		}
	}

	return tx.Commit()
}

func (r *PersonsRepository) DeletePerson(ctx context.Context, idPerson uint, idUser uint64) error {
	res, err := r.DB.ExecContext(ctx, `
		DELETE p FROM Persons p
		INNER JOIN Categories
		ON p.idCategory = Categories.id
		WHERE p.id = ?
		AND idUser = ?
	`, idPerson, idUser)
	if err != nil {
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return nil
}
