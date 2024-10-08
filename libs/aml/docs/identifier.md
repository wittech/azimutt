# AML - Azimutt Markup Language

[back to home](./README.md)


## Identifier

Identifiers are names for objects. You can find them everywhere, for [entities](./entity.md), [attributes](./entity.md#attribute), [namespaces](./namespace.md), [relations](./relation.md) and [types](./type.md)...

They are composed of word characters, so any [snake_case](https://wikipedia.org/wiki/Snake_case) or [CamelCase](https://wikipedia.org/wiki/Camel_case) notation will be fine.

Here is their specific regex: `\b[a-zA-Z_][a-zA-Z0-9_#]*\b`.

If you need to include other characters, such as spaces or special ones, you can escape them using `"`.

Here are valid identifiers:

- `posts`
- `post_authors`
- `"user events"`
