# @azimutt/parser-prisma

This lib is able to parse and generate [Prisma Schema](https://www.prisma.io/docs/orm/prisma-schema) from/to an [Azimutt database model](../models).

**Feel free to use it and even submit PR to improve it:**

- improve [Prisma parser & generator](./src/prisma.ts) (look at `parse` and `generate` functions)

## Publish

- update `package.json` version
- update lib versions (`pnpm -w run update` + manual)
- test with `pnpm run dry-publish` and check `azimutt-parser-prisma-x.y.z.tgz` content
- launch `pnpm publish --no-git-checks --access public`

View it on [npm](https://www.npmjs.com/package/@azimutt/parser-prisma).

## Dev

If you need to develop on multiple libs at the same time (ex: want to update a connector and try it through the CLI), depend on local libs but publish & revert before commit.

- Depend on a local lib: `pnpm add <lib>`, ex: `pnpm add @azimutt/models`
- "Publish" lib locally by building it: `pnpm run build`
