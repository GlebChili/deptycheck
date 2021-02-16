module Example.Pil.Lang.Common

import public Data.Vect

import Decidable.Equality

import Syntax.WithProof

%default total

namespace Types

  --- Available types in the system ---

  public export
  data Type' = Bool' | Int' | String'

  public export
  idrTypeOf : Type' -> Type
  idrTypeOf Bool'   = Bool
  idrTypeOf Int'    = Int
  idrTypeOf String' = String

  export
  DecEq Type' where
    decEq Bool'   Bool'   = Yes Refl
    decEq Int'    Int'    = Yes Refl
    decEq String' String' = Yes Refl

    decEq Bool'   Int'    = No \case Refl impossible
    decEq Bool'   String' = No \case Refl impossible

    decEq Int'    Bool'   = No \case Refl impossible
    decEq Int'    String' = No \case Refl impossible

    decEq String' Bool'   = No \case Refl impossible
    decEq String' Int'    = No \case Refl impossible

namespace Auxiliary

  --- Auxiliary data definitions and their instances ---

  export
  data Name = MkName String

  %name Name n, m

  export
  FromString Name where
    fromString = MkName

  export
  Eq Name where
    MkName n == MkName m = n == m

  export
  Show Name where
    show (MkName n) = n

namespace Invariant

  --- Static context in terms of which we are formulating an invariant ---

  namespace Variable

    public export
    Variables : Type
    Variables = List (Name, Type')

    %name Variables vars

  namespace Register

    public export
    data Registers : Nat -> Type where
      Base  : Vect rc $ Maybe Type' -> Registers rc
      Merge : Registers rc -> Registers rc -> Registers rc

    %name Registers regs

    public export
    AllUndefined : {rc : Nat} -> Registers rc
    AllUndefined = Base $ replicate rc Nothing

    --- Rules of merging of independent register types ---

    public export
    mergeSame : Maybe Type' -> Maybe Type' -> Maybe Type'
    mergeSame Nothing  _        = Nothing
    mergeSame (Just _) Nothing  = Nothing
    mergeSame (Just x) (Just y) = case decEq x y of
      Yes _ => Just x
      No  _ => Nothing

    namespace MergeSameProperties

      export
      mergeSame_idempotent : (x : _) -> mergeSame x x = x
      mergeSame_idempotent Nothing = Refl
      mergeSame_idempotent (Just x) = rewrite decEqSelfIsYes {x} in Refl

      export
      mergeSame_commutative : (x, y : _) -> mergeSame x y = mergeSame y x
      mergeSame_commutative Nothing  Nothing  = Refl
      mergeSame_commutative Nothing  (Just _) = Refl
      mergeSame_commutative (Just _) Nothing  = Refl
      mergeSame_commutative (Just x) (Just y) with (decEq x y)
        mergeSame_commutative (Just x) (Just y) | No uxy with (decEq y x)
          mergeSame_commutative (Just _) (Just _) | No _   | No _   = Refl
          mergeSame_commutative (Just _) (Just _) | No uxy | Yes yx = absurd $ uxy $ sym yx
        mergeSame_commutative (Just x) (Just y) | Yes xy = rewrite sym xy in
                                                           rewrite decEqSelfIsYes {x} in
                                                           Refl

      export
      mergeSame_nothing_absorbs_r : (x : _) -> mergeSame x Nothing = Nothing
      mergeSame_nothing_absorbs_r Nothing  = Refl
      mergeSame_nothing_absorbs_r (Just _) = Refl

      -- To be removed from here as soon as PR#1072 is merged.
      decEqContraIsNo : DecEq a => {x, y : a} -> (x = y -> Void) -> (p ** decEq x y = No p)
      decEqContraIsNo uxy with (decEq x y)
        decEqContraIsNo uxy | Yes xy = absurd $ uxy xy
        decEqContraIsNo _   | No uxy = (uxy ** Refl)

      export
      mergeSame_associative : (x, y, z : _) -> (x `mergeSame` y) `mergeSame` z = x `mergeSame` (y `mergeSame` z)
      mergeSame_associative Nothing  _        _        = Refl
      mergeSame_associative (Just x) Nothing  _        = Refl
      mergeSame_associative (Just x) (Just y) Nothing  = mergeSame_nothing_absorbs_r _
      mergeSame_associative (Just x) (Just y) (Just z) with (decEq x y)
        mergeSame_associative (Just x) (Just y) (Just z) | Yes xy = rewrite xy in
                                                                    case @@ decEq y z of
                                                                      (Yes _ ** p) => rewrite p in
                                                                                      rewrite decEqSelfIsYes {x=y} in
                                                                                      Refl
                                                                      (No _ ** p) => rewrite p in Refl
        mergeSame_associative (Just x) (Just y) (Just z) | No uxy with (decEq y z)
          mergeSame_associative (Just x) (Just y) (Just z) | No uxy | Yes yz = rewrite snd $ decEqContraIsNo uxy in Refl
          mergeSame_associative (Just x) (Just y) (Just z) | No uxy | No uyz = Refl

    --- The main eliminator for the `Registers` type ---

    public export
    index : Fin rc -> Registers rc -> Maybe Type'
    index i $ Base xs     = Vect.index i xs
    index i $ Merge r1 r2 = mergeSame (index i r1) (index i r2)

    --- Index-equivalence relation ---

    infix 0 =%=

    -- Extensional equality regarding to the `index` function for any possible indexing argument.
    public export
    data (=%=) : Registers rc -> Registers rc -> Type where
      EquivByIndex : {0 l, r : Registers rc} -> ((i : Fin rc) -> index i l = index i r) -> l =%= r

    public export %inline
    (.ieq) : x =%= y -> (i : _) -> index i x = index i y
    (.ieq) (EquivByIndex f) = f

    export %hint
    index_equiv_refl : x =%= x
    index_equiv_refl = EquivByIndex \_ => Refl

    export %hint
    index_equiv_sym : x =%= y -> y =%= x
    index_equiv_sym xy = EquivByIndex \i => sym $ xy.ieq i

    export %hint
    index_equiv_trans : x =%= y -> y =%= z -> x =%= z
    index_equiv_trans xy yz = EquivByIndex \i => trans (xy.ieq i) (yz.ieq i)

    --- Equivalence properties of `Merge` ---

    export %hint
    merge_commutative : {l, r : _} -> Merge l r =%= Merge r l
    merge_commutative = EquivByIndex \i => mergeSame_commutative _ _

    export %hint
    merge_associative : {a, b, c : _} -> (a `Merge` b) `Merge` c =%= a `Merge` (b `Merge` c)
    merge_associative = EquivByIndex \i => mergeSame_associative _ _ _

    export %hint
    merge_idempotent : {x : _} -> Merge x x =%= x
    merge_idempotent = EquivByIndex \i => mergeSame_idempotent _
