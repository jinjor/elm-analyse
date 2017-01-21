module DeclarationsTests exposing (..)

import Combine exposing ((*>), Parser)
import CombineTestUtil exposing (..)
import Expect
import Parser.Declarations as Parser exposing (..)
import Parser.Imports exposing (importDefinition)
import Parser.Modules exposing (moduleDefinition)
import Parser.Patterns exposing (..)
import Parser.Types as Types exposing (..)
import Parser.Util exposing (exactIndentWhitespace)
import Test exposing (..)


all : Test
all =
    describe "DeclarationTests"
        [ test "normal signature" <|
            \() ->
                parseFullStringWithNullState "foo : Int" Parser.signature
                    |> Expect.equal
                        (Just
                            { name = "foo"
                            , typeReference = Types.Typed [] "Int" []
                            }
                        )
        , test "no spacing signature" <|
            \() ->
                parseFullStringWithNullState "foo:Int" Parser.signature
                    |> Expect.equal
                        (Just
                            { name = "foo"
                            , typeReference = Types.Typed [] "Int" []
                            }
                        )
        , test "on newline signature with wrong indent " <|
            \() ->
                parseFullStringWithNullState "foo :\nInt" Parser.signature
                    |> Expect.equal Nothing
        , test "on newline signature with good indent" <|
            \() ->
                parseFullStringWithNullState "foo :\n Int" Parser.signature
                    |> Expect.equal
                        (Just
                            { name = "foo"
                            , typeReference = Types.Typed [] "Int" []
                            }
                        )
        , test "on newline signature with colon on start of line" <|
            \() ->
                parseFullStringWithNullState "foo\n:\n Int" Parser.signature
                    |> Expect.equal Nothing
        , test "function declaration" <|
            \() ->
                parseFullStringWithNullState "foo = bar" Parser.functionDeclaration
                    |> Expect.equal (Just { name = "foo", arguments = [], expression = (FunctionOrValue "bar") })
        , test "function declaration with args" <|
            \() ->
                parseFullStringWithNullState "inc x = x + 1" Parser.functionDeclaration
                    |> Expect.equal
                        (Just
                            { name = "inc"
                            , arguments = [ VarPattern "x" ]
                            , expression =
                                (Application
                                    [ FunctionOrValue "x"
                                    , Operator "+"
                                    , Integer 1
                                    ]
                                )
                            }
                        )
        , test "some signature" <|
            \() ->
                parseFullStringWithNullState "bar : List ( Int , Maybe m )" Parser.signature
                    |> Expect.equal
                        (Just
                            { name = "bar"
                            , typeReference =
                                Typed []
                                    "List"
                                    [ Concrete
                                        (Tupled
                                            [ Typed [] "Int" []
                                            , Typed [] "Maybe" [ Generic "m" ]
                                            ]
                                        )
                                    ]
                            }
                        )
        , test "function declaration with let" <|
            \() ->
                parseFullStringWithNullState "foo =\n let\n  b = 1\n in\n  b" Parser.functionDeclaration
                    |> Expect.equal
                        (Just
                            { name = "foo"
                            , arguments = []
                            , expression =
                                (LetBlock
                                    [ FuncDecl
                                        { documentation = Nothing
                                        , signature = Nothing
                                        , declaration =
                                            { name = "b"
                                            , arguments = []
                                            , expression = Integer 1
                                            }
                                        }
                                    ]
                                    (FunctionOrValue "b")
                                )
                            }
                        )
        , test "declaration with record" <|
            \() ->
                parseFullStringWithNullState "main =\n  beginnerProgram { model = 0, view = view, update = update }" Parser.functionDeclaration
                    |> Expect.equal
                        (Just
                            { name = "main"
                            , arguments = []
                            , expression =
                                (Application
                                    [ FunctionOrValue "beginnerProgram"
                                    , RecordExpr
                                        [ ( "model", Integer 0 )
                                        , ( "view", FunctionOrValue "view" )
                                        , ( "update", FunctionOrValue "update" )
                                        ]
                                    ]
                                )
                            }
                        )
        , test "update function" <|
            \() ->
                parseFullStringWithNullState "update msg model =\n  case msg of\n    Increment ->\n      model + 1\n\n    Decrement ->\n      model - 1" Parser.functionDeclaration
                    |> Expect.equal
                        (Just
                            { name = "update"
                            , arguments = [ VarPattern "msg", VarPattern "model" ]
                            , expression =
                                (CaseBlock
                                    (FunctionOrValue "msg")
                                    [ ( NamedPattern [] "Increment" []
                                      , Application [ FunctionOrValue "model", Operator "+", Integer 1 ]
                                      )
                                    , ( NamedPattern [] "Decrement" []
                                      , Application [ FunctionOrValue "model", Operator "-", Integer 1 ]
                                      )
                                    ]
                                )
                            }
                        )
        , test "port declaration" <|
            \() ->
                parseFullStringWithNullState "port parseResponse : ( String, String ) -> Cmd msg" Parser.portDeclaration
                    |> Expect.equal
                        (Just
                            (PortDeclaration
                                { name = "parseResponse"
                                , typeReference =
                                    (Types.Function
                                        (Tupled [ Typed [] "String" [], Typed [] "String" [] ])
                                        (Typed [] "Cmd" [ Generic "msg" ])
                                    )
                                }
                            )
                        )
        , test "no-module and then import" <|
            \() ->
                parseFullStringWithNullState "import Html" file
                    |> Expect.equal
                        (Just
                            { moduleDefinition =
                                NoModule
                            , imports =
                                [ { moduleName = ModuleName [ "Html" ]
                                  , moduleAlias = Nothing
                                  , exposingList = Types.None
                                  }
                                ]
                            , declarations = []
                            }
                        )
        ]


moduleAndImport : Parser Types.State Types.Import
moduleAndImport =
    (moduleDefinition *> exactIndentWhitespace *> importDefinition)
