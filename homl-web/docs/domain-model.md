# Domain model

Curated view of the backend domain layer (`src/internal/domain`). The code is
the source of truth — regenerate this document whenever an aggregate changes.

The domain is split into three aggregates (`user`, `category`, `event`)
plus a static reference-data package (`masterdata`). Each aggregate
package holds its entities, value objects, DTOs and a `Repository` interface
that acts as its persistence port (implemented in
`src/internal/infrastructure/persistence`).

## Aggregates and relations

```mermaid
classDiagram
    direction LR

    %% UserAggregate
    class User {
        +uint64 ID
        +string Username
        +string Password
        +bool IsFingerprintEnabled
        +bool IsPinEnabled
        +string Pin
        +uint PinTryCounter
        +string Pkey
        +string Challenge
    }
    class Settings {
        <<value object>>
        +Language Language
        +bool DefaultScreen
    }
    class TokenDetails {
        <<value object>>
        +string AccessToken
        +string RefreshToken
        +string AccessUuid
        +string RefreshUuid
        +int64 AtExpires
        +int64 RtExpires
    }
    class AccessDetails {
        <<value object>>
        +string AccessUuid
        +uint64 UserId
    }
    class RefreshDetails {
        <<value object>>
        +string RefreshUuid
        +uint64 UserId
    }

    %% CategoryAggregate
    class Category {
        +uint Id
        +string Category
        +string Color
        +bool IsLocked
        +Kind Kind
        +uint64 IdUser
    }
    class Tag {
        +uint Id
        +string Tag
        +uint IdCategory
        +*uint IdParentTag
    }

    %% EventAggregate
    class Event {
        +uint Id
        +string Description
        +time.Time Date
    }

    %% Masterdata
    class DefaultCategory {
        <<reference data>>
        +string Name
        +string Color
        +string Kind
        +bool Locked
    }

    User "1" *-- "1" Settings : stored on Users row
    User "1" o-- "0..*" Category : owns
    Category "1" *-- "0..*" Tag : owns lifecycle
    Tag "0..*" --> "0..1" Tag : synonym (IdParentTag)
    Event "0..*" -- "0..*" Tag : EventsTags join table
    DefaultCategory ..> Category : seeded at registration
```

## Aggregate notes

### User (`domain/user`)

- Root of authentication and per-user configuration. Passwords are bcrypt
  hashed (`PasswordBcryptCost = 12`); the pin uses a lower cost and is
  protected by a hard lockout (`PinTryCounter`).
- `Settings` is a value object with no identity of its own — one row per
  user, persisted as columns of the `Users` table (`language`,
  `defaultScreen`).
- `TokenDetails`, `AccessDetails` and `RefreshDetails` are auth value objects;
  token state lives in Redis, the rest of the aggregate in MySQL.
- Registration creates the user **and** its default categories in one
  transaction (see [Masterdata](#masterdata-domainmasterdata)).

### Category (`domain/category`)

- Root of the tagging system. A `Tag` never exists without its owning
  category: its lifecycle (move on category delete, blacklist rules) is
  enforced through the category root, and tag persistence operations live on
  the category `Repository`.
- `Kind` identifies the role of a category (`date`, `person`, `other`,
  `custom`); `IsLocked` marks the ones that are fully read-only for the user
  (the seeded date and other categories — the seeded person category is a
  plain unlocked suggestion). See
  [default-categories.md](default-categories.md) for the full rules.
- A tag may reference another tag of the same category as its parent
  (`IdParentTag`): synonyms, one level deep, available in every category
  except the date one (see [tag-synonyms.md](tag-synonyms.md)). A "person"
  is not a dedicated aggregate: it is an ordinary tag (plus synonyms for its
  alternative names) in whatever category the user likes.

### Event (`domain/event`)

- An event is a dated description linked to any number of tags through the
  `EventsTags` join table (scoped by user).

### Masterdata (`domain/masterdata`)

- Static reference data embedded in the binary at build time
  (`constants.json`): the default categories seeded for every new user (the
  first one is the "Dates" category) and the blacklisted tag names users are
  not allowed to create.

## Persistence ports

Each aggregate exposes one `Repository` interface, implemented against MySQL
(and Redis for auth) in `infrastructure/persistence`. Fields prefixed `enc` in
port signatures are encrypted at rest by the application layer before
crossing the port.

| Port | Responsibilities |
| --- | --- |
| `user.Repository` | Registration (user + default categories, transactional), lookup, password/pin/fingerprint updates, Redis auth tokens, single-use password-reset tokens, settings read/write |
| `category.Repository` | Category CRUD (delete moves the tags to Others or removes them with their exclusive events), tag CRUD (synonyms included, moving a main tag takes its synonyms along), tag lookup by name, usage counts (`TagUsage`, `CategoryUsage`) |
| `event.Repository` | Event CRUD with tags, per-user listing |

## DTOs

Response/input shapes colocated with their aggregate, used by the application
and web layers: `user.UserResponse`, `user.UserPassword`, `user.RefreshInput`,
`user.SettingsResponse`, `category.GetCategoryResponse`, `category.TagDTO`,
`event.GetEventsResponse`.
