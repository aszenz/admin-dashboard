module Router exposing
  ( Model
  , Msg(..)
  , init
  , transitionTrigger
  , update
  , view
  )


import Html as Html exposing (..)
import Browser
import Browser.Navigation as Nav
import RemoteData
import Url exposing (Url)
import Url.Parser as Parser exposing (Parser, oneOf, s, int, (</>))



import Routes.Home as Home
import Routes.Dash as Dash 
import Session
import SharedState exposing (SharedState, SharedStateUpdate)



{-
Once the application gets more complex,
you can import the models from various routes

import Routes.Home as Home
import Routes.Settings as Settings

type alias Model =
  { home     : Home.Model
  , settings : Settings.Model
  , .....
  , route    : Route
  }
-}


type Route
  = Home Home.Model
  | Dash Dash.Model
  | Site Int
  | NotFound


type alias Model = Route


type Msg
  = UrlChange Url
  | HomeMsg Home.Model Home.Msg
  | DashMsg Dash.Model Dash.Msg


parser : Parser (Route -> a) a
parser =
  oneOf
    [ Parser.map (Home Home.init) Parser.top
    , Parser.map (Dash Dash.init) (s "dash")
    , Parser.map Site (s "sites" </> int)
    ]

fromUrl : Url -> Model
fromUrl = Maybe.withDefault NotFound << Parser.parse parser


init : Url -> SharedState -> ( Model, Cmd Msg )
init url sharedState =
  let
    model = fromUrl url

  in
  ( model
  , transitionTrigger model sharedState
  )



-- trigger commands on page transitions
-- and initializations
transitionTrigger : Route -> SharedState -> Cmd Msg
transitionTrigger route { session, api, navKey } =
  case ( route, session ) of
    ( Dash dashModel , (Session.Admin ( _, token )) ) ->
      Cmd.map (DashMsg dashModel) <| Dash.initRoute token api navKey

    -- redirect guests on private routes
    ( Dash _, Session.Guest ) ->
      Nav.pushUrl navKey "/"

    ( Site _, Session.Guest ) ->
      Nav.pushUrl navKey "/"
    
    _ -> Cmd.none


update : SharedState -> Msg -> Model -> ( Model, Cmd Msg, SharedStateUpdate )
update state msg model =
  case msg of
    UrlChange url -> 
      let
        route = fromUrl url

        transitionTriggerMsg = transitionTrigger route state

      in
      ( route
      , transitionTriggerMsg
      , SharedState.NoUpdate
      )
      
    HomeMsg homeModel homeMsg ->
      let 
        ( newModel, homeCmd, sharedStateUpdate ) =
          Home.update state homeMsg homeModel
      in
        ( Home newModel
        , Cmd.map (HomeMsg newModel) homeCmd
        , sharedStateUpdate
        )

    DashMsg dashModel dashMsg ->
      let
        ( newModel, dashCmd, sharedStateUpdate ) =
          Dash.update state dashMsg dashModel
      in
      ( Dash newModel
      , Cmd.map (DashMsg dashModel) dashCmd
      , sharedStateUpdate
      )



view : (Msg -> msg) -> SharedState -> Model -> Browser.Document msg
view toMsg sharedState routerModel =
  let
    ( title, html ) =
      case routerModel of
        Home homeModel ->
          Home.view sharedState.session homeModel
          |> Tuple.mapSecond (Html.map <| HomeMsg homeModel)
          |> Tuple.mapSecond (Html.map toMsg)
          

        Dash dashModel ->
          case sharedState.session of
            Session.Guest ->
              ( "Redirecting ..."
              , div [] [ text "Redirecting ..."]
              )
            
            Session.Admin ( admin, _ ) -> 
              Dash.view sharedState admin dashModel
              |> Tuple.mapSecond (Html.map <| DashMsg dashModel)
              |> Tuple.mapSecond (Html.map toMsg)


        Site siteId ->
          ( "Site: " ++ (String.fromInt siteId)
          , div [ ] [ text "yey" ]
          )

        NotFound ->
          ( "Woops!", div [] [ text "404 Not Found"] )

  in
  { title = title ++ " | Parlez-Vous "
  , body = [ html ]
  }