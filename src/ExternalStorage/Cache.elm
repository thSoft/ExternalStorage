module ExternalStorage.Cache (
  Cache,
  create,
  Update) where

{-|
# Defining a cache
@docs Cache, create, Update
-}

import Dict exposing (..)
import Signal exposing (..)
import Json.Decode exposing (..)

{-| Stores JSON values (potentially coming from an external storage) associated with their URLs.

    cache : Signal Cache
-}
type alias Cache = Dict String Value

{-| Maintains the state of a cache by processing an update feed.

    cache = feed |> Cache.create
-}
create : Signal Update -> Signal Cache
create feed = feed |> foldp update empty

update : Update -> Cache -> Cache
update entry cache =
  case entry of
    Nothing -> cache
    Just { url, value } ->
      case value of 
        Just realValue -> cache |> insert url realValue
        Nothing -> cache |> remove url

{-| A cache update command.
Indicates that a new value has to be inserted to the cache or an existing value has to be removed from it.

    port feed : Signal Cache.Update
-}
type alias Update = Maybe {
  url: String,
  value: Maybe Value
}