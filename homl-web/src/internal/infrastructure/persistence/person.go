package persistence

import (
	"context"

	"github.com/alkariin/homl/homl-web/internal/apperror"
	"github.com/alkariin/homl/homl-web/internal/domain/person"
	"github.com/jmoiron/sqlx"
)

type PersonsRepository struct {
	DB *sqlx.DB
}

func NewPersonsRepository(db *sqlx.DB) person.Repository {
	return &PersonsRepository{
		DB: db,
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

func (r *PersonsRepository) FindAllByUser(ctx context.Context, idUser uint64) ([]person.Person, error) {
	persons := make([]person.Person, 0)
	err := r.DB.SelectContext(ctx, &persons, `
		SELECT p.id, p.firstname, p.lastname
		FROM Persons p
		INNER JOIN Categories c ON p.idCategory = c.id
		WHERE c.idUser = ?
		ORDER BY p.id
	`, idUser)
	if err != nil {
		return nil, err
	}
	return persons, nil
}

func (r *PersonsRepository) CreatePersonWithMainTag(ctx context.Context, encFirstname string, encLastname string, encMainTagName string, idCategoryPerson uint) error {
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

	// The main tag is the only tag carrying the person link; alternative
	// names are plain synonyms created through the tag endpoints.
	_, err = tx.ExecContext(ctx, "INSERT INTO Tags (tag, idCategory, idPerson) VALUES (?, ?, ?)", encMainTagName, idCategoryPerson, idPerson)
	if err != nil {
		return err
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

func (r *PersonsRepository) UpdatePersonWithMainTag(
	ctx context.Context,
	storedPerson *person.Person,
	encFirstname string,
	encLastname string,
	encMainTagName string,
	mainPersonTagId uint,
) error {
	if encFirstname == storedPerson.Firstname && encLastname == storedPerson.Lastname {
		return nil
	}

	tx, err := r.DB.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() // no-op once Commit succeeds

	_, err = tx.ExecContext(ctx, "UPDATE Persons SET firstname = ?, lastname = ? WHERE id = ?", encFirstname, encLastname, storedPerson.Id)
	if err != nil {
		return err
	}

	// The main tag mirrors the person's name.
	_, err = tx.ExecContext(ctx, "UPDATE Tags SET tag = ? WHERE id = ?", encMainTagName, mainPersonTagId)
	if err != nil {
		return err
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
