package persistence

import (
	"context"
	"database/sql"
	"sort"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/application"
	"github.com/alkariin/homl/homl-web/internal/domain/person"
)

type PersonsRepository struct {
	DB     *sql.DB
	Crypto application.Encryptor
}

func NewPersonsRepository(db *sql.DB, crypto application.Encryptor) person.Repository {
	return &PersonsRepository{
		DB:     db,
		Crypto: crypto,
	}
}

func (r *PersonsRepository) FindById(idPerson uint) (*person.Person, error) {
	var person person.Person
	row := r.DB.QueryRow("SELECT id, firstname, lastname FROM Persons WHERE id = ?", idPerson)
	err := row.Scan(&person.Id, &person.Firstname, &person.Lastname)
	if err != nil {
		return nil, err
	}
	return &person, nil
}

func (r *PersonsRepository) FindPersonsWithTagsAndCategories(idUser uint64) (map[uint]person.Person, map[uint][]person.Nickname, error) {
	results, err := r.DB.Query(`
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

	nicknames := make(map[uint][]person.Nickname)
	persons := make(map[uint]person.Person)
	for results.Next() {
		var nickname person.Nickname
		var p person.Person
		err = results.Scan(&p.Id, &p.Firstname, &p.Lastname, &nickname.Id, &nickname.Nickname)
		if err != nil {
			return nil, nil, err
		}

		decNickname, err := r.Crypto.Decrypt(nickname.Nickname)
		if err != nil {
			return nil, nil, err
		}
		nickname = person.Nickname{Id: nickname.Id, Nickname: decNickname}
		nicknames[p.Id] = append(nicknames[p.Id], nickname)
		persons[p.Id] = p
	}

	return persons, nicknames, nil
}

func (r *PersonsRepository) CreatePersonWithTags(encFirstname string, encLastname string, encMainTagName string, idCategoryPerson uint, nicknames []string) error {
	// Insert person
	ctx := context.Background()
	tx, err := r.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx, "INSERT INTO Persons (firstname, lastname, idCategory) VALUES (?, ?, ?)", encFirstname, encLastname, idCategoryPerson)
	if err != nil {
		tx.Rollback()
		return err
	}

	// Get idPerson
	var idPerson uint
	row := tx.QueryRow("SELECT max(id) FROM Persons")
	err = row.Scan(&idPerson)
	if err != nil {
		tx.Rollback()
		return err
	}

	// create main tag
	_, err = tx.ExecContext(ctx, "INSERT INTO Tags (tag, idCategory, idPerson) VALUES (?, ?, ?)", encMainTagName, idCategoryPerson, idPerson)
	if err != nil {
		tx.Rollback()
		return err
	}

	// create nickname tags
	for _, nickname := range nicknames {
		encNickname, err := r.Crypto.Encrypt(nickname)
		if err != nil {
			tx.Rollback()
			return err
		}
		_, err = tx.ExecContext(ctx, "INSERT INTO Tags (tag, idCategory, idPerson) VALUES (?, ?, ?)", encNickname, idCategoryPerson, idPerson)
		if err != nil {
			tx.Rollback()
			return err
		}
	}

	return tx.Commit()
}

func (r *PersonsRepository) CheckPersonIdsWithTagsAndCategories(idUser uint64, idPerson uint) error {
	var personIdToCheck uint
	row := r.DB.QueryRow(`
		SELECT DISTINCT(Persons.id)
		FROM Persons INNER JOIN Tags INNER JOIN Categories
		ON Persons.id = Tags.idPerson
		AND Categories.id = Tags.idCategory
		WHERE Categories.idUser = ?
		AND Persons.id = ?
	`, idUser, idPerson)
	return row.Scan(&personIdToCheck)
}

func (r *PersonsRepository) UpdatePersonWithTags(
	storedPerson *person.Person,
	encFirstname string,
	encLastname string,
	encMainTagName string,
	mainPersonTagId uint,
	idCategoryPerson uint,
	idUser uint64,
	bodyNicknames []person.Nickname,
) error {
	ctx := context.Background()
	tx, err := r.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	if encFirstname != storedPerson.Firstname || encLastname != storedPerson.Lastname {
		_, err = tx.ExecContext(ctx, "UPDATE Persons SET firstname = ?, lastname = ? WHERE id = ?", encFirstname, encLastname, storedPerson.Id)
		if err != nil {
			tx.Rollback()
			return err
		}

		_, err = tx.ExecContext(ctx, "UPDATE Tags SET tag = ? WHERE id = ?", encMainTagName, mainPersonTagId)
		if err != nil {
			tx.Rollback()
			return err
		}
	}

	// Get nicknames of the person
	row2, err := tx.Query(`
		SELECT Tags.id, tag as nickname
		FROM Tags
		INNER JOIN Categories
		ON Tags.idCategory = Categories.id
		WHERE idPerson = ?
		AND idUser = ?
		ORDER BY Tags.id`, storedPerson.Id, idUser)
	if err != nil {
		tx.Rollback()
		return err
	}

	var nicknames []person.Nickname
	for row2.Next() {
		var nickname person.Nickname
		err = row2.Scan(&nickname.Id, &nickname.Nickname)
		if err != nil {
			tx.Rollback()
			return err
		}
		nicknames = append(nicknames, nickname)
	}

	// algo pseudo code:
	// var lastIndex = 0
	// sort personNicknames.nicknames by id
	// for n1 in nicknames (from the db)
	//   for n2, i=lastIndex in body.nicknames (from the params)
	//     lastIndex = i
	//     if (!n2.id) -> INSERT + continue
	//     if (n1.id < n2.id) -> DELETE + break
	//     if (n1.id === n2.id && n1.nickname !== n2.nickname) -> UPDATE + break
	// for (var i = lastIndex; i < body.nicknames.length; i++)
	// If IDs start at 0 from the beginning, this extra offset loop may not be needed.
	//   if (!n2.id) -> INSERT
	// The rest cannot happen in my use case -> do nothing (can be code injection)

	sort.Slice(bodyNicknames, func(i, j int) bool {
		return bodyNicknames[i].Id < bodyNicknames[j].Id
	})

	lastIndex := 0
	for i := 1; i < len(nicknames); i++ { // i=1 to skip the main tag
		n1 := nicknames[i]
		if lastIndex >= len(bodyNicknames) {
			_, err = tx.ExecContext(ctx, "DELETE FROM Tags WHERE id = ?", n1.Id)
			if err != nil {
				tx.Rollback()
				return err
			}
		} else {
			for j := lastIndex; j < len(bodyNicknames); j++ {
				n2 := bodyNicknames[j]
				// Insertion of the nickname
				if n2.Id == 0 {
					encNickname, err := r.Crypto.Encrypt(n2.Nickname)
					if err != nil {
						tx.Rollback()
						return err
					}
					_, err = tx.ExecContext(ctx, "INSERT INTO Tags (tag, idCategory, idPerson) VALUES (?, ?, ?)", encNickname, idCategoryPerson, storedPerson.Id)
					if err != nil {
						tx.Rollback()
						return err
					}
					lastIndex++
					continue
				}

				// Deletion of the nickname
				// Update the events_tags to reference the "main" name of the person
				if n1.Id < n2.Id {
					// Update the events_tags
					_, err = tx.ExecContext(ctx, "UPDATE EventsTags SET idTag = ? WHERE idTag = ?", mainPersonTagId, n1.Id)
					if err != nil {
						tx.Rollback()
						return err
					}

					// Delete old tag
					_, err = tx.ExecContext(ctx, "DELETE FROM Tags WHERE id = ?", n1.Id)
					if err != nil {
						tx.Rollback()
						return err
					}

					break
				}

				// Update of the nickname
				encNickname, err := r.Crypto.Encrypt(n2.Nickname)
				if err != nil {
					tx.Rollback()
					return err
				}
				if n1.Id == n2.Id && n1.Nickname != encNickname {
					_, err = tx.ExecContext(ctx, "UPDATE Tags SET tag = ? WHERE id = ?", encNickname, n1.Id)
					if err != nil {
						tx.Rollback()
						return err
					}

					lastIndex++
					break
				}
			}
		}
	}

	return tx.Commit()
}

func (r *PersonsRepository) DeletePerson(idPerson uint, idUser uint64) error {
	ctx := context.Background()
	tx, err := r.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	res, err := tx.ExecContext(ctx, `
		DELETE p FROM Persons p
		INNER JOIN Categories
		ON p.idCategory = Categories.id
		WHERE p.id = ?
		AND idUser = ?
	`, idPerson, idUser)
	if err != nil {
		tx.Rollback()
		return err
	}

	rowsAffected, err := res.RowsAffected()
	if rowsAffected == 0 || err != nil {
		return apperror.NewInternal()
	}

	return tx.Commit()
}
