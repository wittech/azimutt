module DataSources.AmlParser.SourceAdapter exposing (AmlSchema, AmlSchemaError, buildAmlSource, evolve)

import Array
import Conf
import DataSources.AmlParser.AmlParser exposing (AmlColumn, AmlColumnName, AmlColumnRef, AmlNotes, AmlStatement(..), AmlTable)
import DataSources.Helpers exposing (defaultCheckName, defaultIndexName, defaultRelName, defaultUniqueName)
import Dict exposing (Dict)
import Libs.Dict as Dict
import Libs.List as List
import Libs.Nel as Nel exposing (Nel)
import Models.Project.Check exposing (Check)
import Models.Project.Column exposing (Column)
import Models.Project.ColumnName exposing (ColumnName)
import Models.Project.Comment exposing (Comment)
import Models.Project.Index exposing (Index)
import Models.Project.PrimaryKey exposing (PrimaryKey)
import Models.Project.Relation exposing (Relation)
import Models.Project.Source exposing (Source)
import Models.Project.SourceId exposing (SourceId)
import Models.Project.Table exposing (Table)
import Models.Project.TableId as TableId exposing (TableId)
import Models.Project.Unique exposing (Unique)
import Models.SourceInfo exposing (SourceInfo)


type alias AmlSchema =
    { tables : Dict TableId Table
    , relations : List Relation
    , errors : List AmlSchemaError
    }


type alias AmlSchemaError =
    String


buildAmlSource : SourceInfo -> List AmlStatement -> ( List AmlSchemaError, Source )
buildAmlSource source statements =
    let
        schema : AmlSchema
        schema =
            statements |> List.foldl (evolve source.id) (AmlSchema Dict.empty [] [])
    in
    ( schema.errors |> List.reverse
    , { id = source.id
      , name = source.name
      , kind = source.kind
      , content = Array.empty
      , tables = schema.tables
      , relations = schema.relations |> List.reverse
      , enabled = source.enabled
      , fromSample = source.fromSample
      , createdAt = source.createdAt
      , updatedAt = source.updatedAt
      }
    )


evolve : SourceId -> AmlStatement -> AmlSchema -> AmlSchema
evolve source statement schema =
    case statement of
        AmlTableStatement aml ->
            let
                ( table, relations ) =
                    aml |> buildTable source
            in
            schema.tables
                |> Dict.get table.id
                |> Maybe.map (\_ -> { schema | errors = ("Table '" ++ TableId.show table.id ++ "' is already defined") :: schema.errors })
                |> Maybe.withDefault { schema | tables = schema.tables |> Dict.insert table.id table, relations = relations ++ schema.relations }

        AmlRelationStatement aml ->
            let
                relation : Relation
                relation =
                    buildRelation source aml.from aml.to
            in
            { schema | relations = relation :: schema.relations }

        AmlEmptyStatement _ ->
            schema


buildTable : SourceId -> AmlTable -> ( Table, List Relation )
buildTable source table =
    ( { id = ( table.schema |> Maybe.withDefault Conf.schema.default, table.table )
      , schema = table.schema |> Maybe.withDefault Conf.schema.default
      , name = table.table
      , view = table.isView
      , columns = table.columns |> List.indexedMap (buildColumn source) |> Dict.fromListMap .name
      , primaryKey = table.columns |> buildPrimaryKey source
      , uniques = table.columns |> buildConstraint .unique (defaultUniqueName table.table) |> List.map (\( name, cols ) -> Unique name cols Nothing [ { id = source, lines = [] } ])
      , indexes = table.columns |> buildConstraint .index (defaultIndexName table.table) |> List.map (\( name, cols ) -> Index name cols Nothing [ { id = source, lines = [] } ])
      , checks = table.columns |> buildConstraint .check (defaultCheckName table.table) |> List.map (\( name, cols ) -> Check name (Nel.toList cols) Nothing [ { id = source, lines = [] } ])
      , comment = table.notes |> Maybe.map (buildComment source)
      , origins = [ { id = source, lines = [] } ]
      }
    , table.columns
        |> List.filterMap (\c -> c.foreignKey |> Maybe.map (\fk -> ( c, fk )))
        |> List.map (\( c, fk ) -> buildRelation source { schema = table.schema, table = table.table, column = c.name } fk)
    )


buildColumn : SourceId -> Int -> AmlColumn -> Column
buildColumn source index column =
    { index = index
    , name = column.name
    , kind = column.kind |> Maybe.withDefault Conf.schema.column.unknownType
    , nullable = column.nullable
    , default = column.default
    , comment = column.notes |> Maybe.map (buildComment source)
    , origins = [ { id = source, lines = [] } ]
    }


buildPrimaryKey : SourceId -> List AmlColumn -> Maybe PrimaryKey
buildPrimaryKey source columns =
    columns
        |> List.filter .primaryKey
        |> List.map .name
        |> Nel.fromList
        |> Maybe.map
            (\cols ->
                { name = Nothing
                , columns = cols
                , origins = [ { id = source, lines = [] } ]
                }
            )


buildConstraint : (AmlColumn -> Maybe String) -> (AmlColumnName -> String) -> List AmlColumn -> List ( String, Nel ColumnName )
buildConstraint get defaultName columns =
    columns
        |> List.filter (\c -> get c /= Nothing)
        |> List.groupBy (\c -> c |> get |> Maybe.withDefault "")
        |> Dict.toList
        |> List.foldl
            (\( name, cols ) acc ->
                if name == "" then
                    (cols |> List.map (\c -> ( defaultName c.name, Nel.from c.name ))) ++ acc

                else
                    ( name, cols |> List.map .name |> Nel.fromList |> Maybe.withDefault (Nel.from name) ) :: acc
            )
            []


buildComment : SourceId -> AmlNotes -> Comment
buildComment source notes =
    { text = notes
    , origins = [ { id = source, lines = [] } ]
    }


buildRelation : SourceId -> AmlColumnRef -> AmlColumnRef -> Relation
buildRelation source from to =
    let
        fromId : TableId
        fromId =
            ( from.schema |> Maybe.withDefault Conf.schema.default, from.table )

        toId : TableId
        toId =
            ( to.schema |> Maybe.withDefault Conf.schema.default, to.table )
    in
    { id = ( ( fromId, from.column ), ( toId, to.column ) )
    , name = defaultRelName from.table from.column
    , src = { table = fromId, column = from.column }
    , ref = { table = toId, column = to.column }
    , origins = [ { id = source, lines = [] } ]
    }