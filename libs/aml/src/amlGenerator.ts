import {isNever, partition, zip} from "@azimutt/utils";
import {
    Attribute,
    attributeExtraKeys,
    attributeExtraProps,
    AttributePath,
    attributePathSame,
    AttributeValue,
    Check,
    Database,
    Entity,
    entityExtraKeys,
    entityExtraProps,
    entityRefSame,
    entityToNamespace,
    entityToRef,
    Extra,
    flattenAttributes,
    legacyColumnTypeUnknown,
    Namespace,
    Relation,
    relationExtraKeys,
    relationExtraProps,
    RelationLink,
    Type,
    typeExtraKeys,
    typeExtraProps,
    typeRefFromId,
    typeRefToId,
    typeToId
} from "@azimutt/models";
import {amlKeywords, PropertyValue} from "./amlAst";


export function genDatabase(database: Database, legacy: boolean): string {
    const [entityRels, aloneRels] = partition(database.relations || [], r => {
        const statement = r.extra?.statement
        return r.extra?.inline ? !!database.entities?.find(e => entityRefSame(entityToRef(e), r.src)) :
            statement ? !!database.entities?.find(e => e.extra?.statement === statement) :
                false
    })
    const [entityTypes, aloneTypes] = partition(database.types || [], t => {
        const tId = typeToId(t)
        const statement = t.extra?.statement
        return t.extra?.inline ? !!database.entities?.find(e => !!flattenAttributes(e.attrs).find(a => a.type === tId || typeRefToId({...typeRefFromId(a.type), ...entityToNamespace(e)}) === tId)) :
            statement ? !!database.entities?.find(e => e.extra?.statement === statement) :
                false
    })
    const entities = (database.entities || []).map((e, i) => {
        const ref = entityToRef(e)
        const rels = entityRels.filter(r => r.extra?.statement ? r.extra?.statement === e.extra?.statement : entityRefSame(r.src, ref))
        return {index: e.extra?.line || i, kind: 'entity', aml: genEntity(e, getCurrentNamespace(database, e), rels, entityTypes, legacy)}
    })
    const entityCount = entities.length
    const relations = aloneRels.map((r, i) => {
        return {index: r.extra?.line || entityCount + i, kind: 'relation', aml: genRelation(r, getCurrentNamespace(database, r), legacy)}
    }).filter(r => r.aml)
    const relationsCount = relations.length
    const types = aloneTypes.map((t, i) => {
        return {index: t.extra?.line || entityCount + relationsCount + i, kind: 'type', aml: genType(t, getCurrentNamespace(database, t), legacy)}
    }).filter(t => t.aml)
    const comments = Array.isArray(database.extra?.comments) ? database.extra.comments.map(c => {
        return {index: c.line, kind: 'comment', aml: genComment(c.comment).trim() + '\n'}
    }) : []
    const namespaces = !legacy && Array.isArray(database.extra?.namespaces) ? database.extra.namespaces.map(n => {
        return {index: n.line, kind: 'namespace', aml: genNamespace(n, n.comment).trim() + '\n'}
    }) : []
    const statements = entities.concat(relations, types, comments, namespaces).sort((a, b) => a.index - b.index)
    return statements.map((statement, i) => {
        if (i === 0) return statement.aml
        const prev = statements[i - 1]
        const newLine = statement.kind === 'entity' || statement.kind !== prev.kind ? '\n' : ''
        return newLine + statement.aml
    }).join('') || ''
}

function getCurrentNamespace(database: Database, s: {extra?: {line?: number}}): Namespace {
    const line = s.extra?.line
    if (!line) return {}
    const namespaces = (database.extra?.namespaces || []).filter(n => n.line < line)
    return namespaces[namespaces.length - 1] || {}
}

export function genEntity(e: Entity, namespace: Namespace, relations: Relation[], types: Type[], legacy: boolean): string {
    const legacyView = e.kind === 'view' && legacy ? '*' : ''
    const alias = e.extra?.alias && !legacy ? ' as ' + genIdentifier(e.extra.alias) : ''
    const props = !legacy ? genProperties(e.extra, e.kind === 'view' && !legacy ? {view: e.def?.replaceAll(/\n/g, '\\n')} : {}, entityExtraKeys.filter(k => !entityExtraProps.includes(k))) : ''
    const entity = `${genName(e, namespace, legacy)}${legacyView}${alias}${props}${genDoc(e.doc, legacy)}${genComment(e.extra?.comment)}\n`
    return entity + (e.attrs ? e.attrs.map(a => genAttribute(a, e, namespace, relations.filter(r => r.src.attrs[0][0] === a.name), types, legacy)).join('') : '')
}

function genAttribute(a: Attribute, e: Entity, namespace: Namespace, relations: Relation[], types: Type[], legacy: boolean, parents: AttributePath = []): string {
    const path = [...parents, a.name]
    const indent = '  '.repeat(path.length)
    const attrRelations = relations.filter(r => attributePathSame(path, r.src.attrs[0]))
    const nested = !legacy ? a.attrs?.map(aa => genAttribute(aa, e, namespace, relations, types, legacy, path)).join('') || '' : ''
    return indent + genAttributeInner(a, e, namespace, attrRelations, types, path, indent, legacy) + '\n' + nested
}

function genAttributeInner(a: Attribute, e: Entity, namespace: Namespace, relations: Relation[], types: Type[], path: AttributePath, indent: string, legacy: boolean): string {
    const pk = e.pk && e.pk.attrs.some(attr => attributePathSame(attr, path)) ? ` pk${e.pk.name && !legacy ? `=${genIdentifier(e.pk.name)}` : ''}` : ''
    const indexes = (e.indexes || [])
        .map((idx, i) => ({...idx, name: idx.name || (idx.attrs.length > 1 ? `${e.name}_idx_${i + 1}` : undefined)}))
        .filter(i => i.attrs.some(attr => attributePathSame(attr, path)))
        .map(i => ` ${i.unique ? 'unique' : 'index'}${i.name ? `=${genIdentifier(i.name)}` : ''}`)
        .join('')
    const checks = (e.checks || []).filter(c => c.attrs.some(attr => attributePathSame(attr, path))).map(c => ' ' + genCheck(c, path, legacy)).join('')
    const rel = relations.map(r => ' ' + genRelationTarget(r, namespace, false, legacy)).join('')
    const props = !legacy ? genProperties(a.extra, {}, attributeExtraKeys.filter(k => !attributeExtraProps.includes(k))) : ''
    return `${genIdentifier(a.name)}${genAttributeType(a, types)}${a.null ? ' nullable' : ''}${pk}${indexes}${checks}${rel}${props}${genDoc(a.doc, legacy, indent)}${genComment(a.extra?.comment)}`
}

function genAttributeType(a: Attribute, types: Type[]): string {
    // regex from `Identifier` token to know if it should be escaped or not (cf libs/aml/src/parser.ts:7)
    const typeName = a.type && a.type !== legacyColumnTypeUnknown ? ' ' + (a.type.match(/^[a-zA-Z_][a-zA-Z0-9_#(),]*$/) ? a.type : genIdentifier(a.type)) : '' // allow unescaped `varchar(10)`
    const enumType = types.find(t => t.name === a.type && t.values)
    const enumValues = enumType ? '(' + enumType.values?.map(genAttributeValueStr).join(', ') + ')' : ''
    const defaultValue = a.default !== undefined ? `=${genAttributeValue(a.default)}` : ''
    return typeName ? typeName + enumValues + defaultValue : ''
}

function genAttributeValue(v: AttributeValue): string {
    if (v === undefined) return ''
    if (v === null) return 'null'
    if (typeof v === 'string') return v.startsWith('`') ? v : genIdentifier(v)
    if (typeof v === 'number') return v.toString()
    if (typeof v === 'boolean') return v.toString()
    return `${v}`
}

function genAttributeValueStr(value: string): string {
    if (value.match(/^\d+(\.\d+)?$/)) return value
    if (value.match(/^true|false$/i)) return value
    return genIdentifier(value)
}

function genCheck(c: Check, path: AttributePath, legacy: boolean) {
    const predicate = c.predicate ? (legacy ? `=${genIdentifier(c.predicate)}` : (attributePathSame(c.attrs[0], path) ? `(\`${c.predicate}\`)` : '')) : ''
    const name = c.name ? (!legacy ? `=${genIdentifier(c.name)}` : '') : ''
    return `check${predicate}${name}`
}

function genRelation(r: Relation, namespace: Namespace, legacy: boolean): string {
    if (legacy && r.src.attrs.length > 1) return zip(r.src.attrs, r.ref.attrs).map(([srcAttr, refAttr]) => genRelation({...r, src: {...r.src, attrs: [srcAttr]}, ref: {...r.ref, attrs: [refAttr]}}, namespace, legacy)).join('') // in v1 composite relations are defined as several relations
    if (legacy && (r.extra?.natural === 'both' || r.extra?.natural === 'src')) return '' // v1 doesn't support src natural relation
    const srcNatural: boolean = !r.extra?.inline && (r.extra?.natural === 'src' || r.extra?.natural === 'both')
    const props = !legacy ? genProperties(r.extra, {}, relationExtraKeys.filter(k => !relationExtraProps.includes(k))) : ''
    return `${legacy ? 'fk' : 'rel'} ${genAttributeRef(r.src, namespace, srcNatural, r.extra?.srcAlias, legacy)} ${genRelationTarget(r, namespace, true, legacy)}${props}${genDoc(r.doc, legacy)}${genComment(r.extra?.comment)}\n`
}

function genRelationTarget(r: Relation, namespace: Namespace, standalone: boolean, legacy: boolean): string {
    const poly = r.polymorphic && !legacy ? `${r.polymorphic.attribute}=${r.polymorphic.value}` : ''
    const aSecond = (r.src.cardinality || 'n') === 'n' ? '>' : '-'
    const aFirst = (r.ref.cardinality || '1') === 'n' ? '<' : '-'
    const refNatural = r.extra?.natural === 'ref' || r.extra?.natural === 'both'
    return `${legacy && !standalone ? 'fk' : aFirst + poly + aSecond} ${genAttributeRef(r.ref, namespace, refNatural, r.extra?.refAlias, legacy)}`
}

export function genAttributeRef(l: RelationLink, namespace: Namespace, natural: boolean, alias: string | undefined, legacy: boolean): string {
    if (legacy) return `${genName({...l, name: l.entity}, namespace, legacy)}.${l.attrs.map(a => genAttributePath(a, legacy)).join(':')}`
    return `${alias ? alias : genName({...l, name: l.entity}, namespace, legacy)}${natural || l.attrs.length === 0 ? '' : `(${l.attrs.map(a => genAttributePath(a, legacy)).join(', ')})`}`
}

function genAttributePath(p: AttributePath, legacy: boolean): string {
    return p.map(genIdentifier).join(legacy ? ':' : '.')
}

function genType(t: Type, namespace: Namespace, legacy: boolean): string {
    if (legacy) return '' // no type in v1
    const props = genProperties(t.extra, {}, typeExtraKeys.filter(k => !typeExtraProps.includes(k)))
    return `type ${genName(t, namespace, legacy)}${genTypeContent(t, namespace, legacy)}${props}${genDoc(t.doc, legacy)}${genComment(t.extra?.comment)}\n`
}

function genTypeContent(t: Type, namespace: Namespace, legacy: boolean): string {
    if (t.alias) return ' ' + t.alias
    if (t.definition && t.definition.match(/[ (]/)) return ' `' + t.definition + '`'
    if (t.definition) return ' ' + t.definition
    if (t.values) return ' (' + t.values.map(genIdentifier).join(', ') + ')'
    if (t.attrs) return ' {' + t.attrs.map(a => genAttributeInner(a, {name: t.name}, namespace, [], [], [a.name], '', legacy)).join(', ') + '}'
    return ''
}

function genNamespace(n: Namespace, comment: string | undefined): string {
    return `namespace${genNamespaceValue(n)}${genComment(comment)}\n`
}

function genNamespaceValue(n: Namespace): string {
    if (n.database) return ' ' + [n.database, n.catalog, n.schema].map(v => v ? genIdentifier(v) : '').join('.')
    if (n.catalog) return ' ' + [n.catalog, n.schema].map(v => v ? genIdentifier(v) : '').join('.')
    if (n.schema) return ' ' + [n.schema].map(v => v ? genIdentifier(v) : '').join('.')
    return ''
}

function genName(e: Namespace & { name: string }, n: Namespace, legacy: boolean): string {
    if (!legacy && e.database && e.database !== n.database) return [e.database, e.catalog, e.schema, e.name].map(v => v ? genIdentifier(v) : '').join('.')
    if (!legacy && e.catalog && e.catalog !== n.catalog) return [e.catalog, e.schema, e.name].map(v => v ? genIdentifier(v) : '').join('.')
    if (e.schema && e.schema !== n.schema) return [e.schema, e.name].map(v => v ? genIdentifier(v) : '').join('.')
    return genIdentifier(e.name)
}

function genProperties(extra: Extra | undefined, additional: Extra, ignore: string[]): string {
    const entries = Object.entries(additional).concat(Object.entries(extra || {})).filter(([k, ]) => !ignore.includes(k))
    return entries.length > 0 ? ' {' + entries.map(([key, value]) => value !== undefined && value !== null ? `${key}: ${genPropertyValue(value)}` : key).join(', ') + '}' : ''
}

function genPropertyValue(v: PropertyValue): string {
    if (Array.isArray(v)) return '[' + v.map(genPropertyValue).join(', ') + ']'
    if (v === null) return 'null'
    if (typeof v === 'string') return genIdentifier(v)
    if (typeof v === 'number') return v.toString()
    if (typeof v === 'boolean') return v.toString()
    return isNever(v)
}

function genDoc(doc: string | undefined, legacy: boolean, indent: string = ''): string {
    if (!doc) return ''
    if (doc.indexOf('\n') === -1) return ' | ' + doc.replaceAll(/#/g, '\\#')
    return !legacy ? ' |||\n' + doc.split('\n').map(l => indent + '  ' + l + '\n').join('') + indent + '|||' : ' | ' + doc.replaceAll(/#/g, '\\#').replaceAll(/\n/g, ' ') // no multi-line comment in v1
}

function genComment(comment: string | undefined): string {
    return comment !== undefined ? ' # ' + comment : ''
}

function genIdentifier(identifier: string): string {
    if (amlKeywords.includes(identifier.trim().toLowerCase())) return '"' + identifier + '"'
    if (identifier.match(/^[a-zA-Z_][a-zA-Z0-9_#]*$/)) return identifier
    return '"' + identifier + '"'
}
