module DerivedGen

import public Test.DepTyCheck.Gen.Auto

import Generics.Derive

%default total

%language ElabReflection

data X = MkX String

%runElab derive "X" [Generic, Meta, Show]

export
derivedGen : Fuel -> (Fuel -> Gen String) => Gen X
--derivedGen = deriveGen
derivedGen _ = empty
