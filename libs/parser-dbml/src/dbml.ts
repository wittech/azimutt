import * as dbml from "@dbml/core";
import DbmlDatabase from "@dbml/core/types/model_structure/database";
import {errorToString} from "@azimutt/utils";
import {Database, ParserError, ParserErrorLevel, ParserResult} from "@azimutt/models";
import {importDatabase} from "./dbmlImport";
import {exportDatabase} from "./dbmlExport";
import {JsonDatabase} from "./jsonDatabase";

export function parseDbml(content: string, opts: { context?: Database } = {}): ParserResult<Database> {
    try {
        const db: DbmlDatabase = (new dbml.Parser(undefined)).parse(content, 'dbmlv2')
        return ParserResult.success(importDatabase(db))
    } catch (e: unknown) {
        return ParserResult.failure(formatError(e))
    }
}

export function generateDbml(database: Database): string {
    try {
        const json: JsonDatabase = exportDatabase(database)
        const db: DbmlDatabase = (new dbml.Parser(undefined)).parse(JSON.stringify(json), 'json')
        return dbml.ModelExporter.export(db, 'dbml', false)
    } catch (e: unknown) {
        throw formatError(e)
    }
}

// used to make sure the generated DBML contains everything possible (comparing with `generate` function)
export function formatDbml(content: string): string {
    try {
        const db: DbmlDatabase = (new dbml.Parser(undefined)).parse(content, 'dbmlv2')
        return dbml.ModelExporter.export(db, 'dbml', false)
    } catch (e) {
        throw formatError(e)
    }
}

// not defined in `@dbml/core` :/
type DbmlParserError = {
    code: number
    message: string
    location: {
        start: {line: number, column: number}
        end: {line: number, column: number}
    }
}

function formatError(err: unknown): ParserError[] {
    if (Array.isArray(err)) {
        const errors = err as DbmlParserError[]
        return errors.map(e => ({
            message: e.message,
            kind: `DBMLException-${e.code}`,
            level: ParserErrorLevel.enum.error,
            offset: {start: 0, end: 0},
            position: e.location
        }))
    } else if (typeof err === 'object' && err !== null && 'diags' in err) {
        return formatError(err.diags)
    } else {
        return [{message: errorToString(err), kind: `UnknownException`, level: ParserErrorLevel.enum.error, offset: {start: 0, end: 0}, position: {start: {line: 0, column: 0}, end: {line: 0, column: 0}}}]
    }
}
