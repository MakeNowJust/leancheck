-- | Simple property-based testing library based on
--   enumeration of values via lists of lists.
--
-- This is the core module of the library, with the most basic definitions.  If
-- you are looking just to use the library, import and see "Test.Check".
--
-- If you want to understand how the code works, this is the place to start.
--
--
-- Other important modules:
--
-- "Test.Check.Basic" re-exports (almost) everything from this module
--         along with constructors and instances for further arities.
--
-- "Test.Check.Utils" re-exports "Test.Check.Basic"
--         along with functions for advanced Listable instance definitions.
--
-- "Test.Check" re-exports "Test.Check.Utils"
--   along with a TH function to automatically derive Listable instances.
module Test.Check.Core
  (
  -- * Checking and testing
    holds
  , fails
  , exists
  , counterExample
  , counterExamples
  , witness
  , witnesses
  , Testable

  , results
  , arguments
  , resultArguments

  -- * Listing test values
  , Listable(..)

  -- ** Default-weighed listing constructors
  , cons0
  , cons1
  , cons2
  , cons3
  , cons4
  , cons5

  -- ** Custom-weighed listing constructors
  , wcons0
  , wcons1
  , wcons2
  , wcons3
  , wcons4
  , wcons5

  -- ** Combining listings
  , (\++/), (\\//)
  , (>++<)
  , lsProduct
  , lsProductWith

  -- ** Manipulating listings
  , lsmap
  , lsfilter
  , lsConcat
  , lsConcatMap
  , toListing

  -- ** Boolean (property) operators
  , (==>)

  -- ** Misc utilities
  , (\/)
  , (><)
  , productWith
  , zipWith'
  )
where

import Data.Maybe (listToMaybe)


-- | A type is 'Listable' when there exists a function that
--   is able to list (ideally all of) its values.
--
-- Ideally, this type should be defined by a 'listing' function that
-- returns a (possibly infinite) list of finite sub-lists:
--   the first sub-list contains elements of size 0,
--   the second sub-list contains elements of size 1
--   and so on.
-- Size here is defined by the implementor of the type-class instance.
-- From here on, __listing__ is used to refer to this concept.
--
-- For algebraic data types, the general form for 'listing' is:
--
-- > listing = consN ConstructorA
-- >      \++/ consN ConstructorB
-- >      \++/ consN ConstructorC
-- >      \++/ ...
--
-- When defined by 'list', each sub-list in 'listing' is a singleton list
-- (each element of 'list' has +1 size).
--
-- The function 'Test.Check.Derive.deriveListable' from "Test.Check.Derive"
-- can automatically derive instances of this typeclass.
class Listable a where
  listing :: [[a]]
  list :: [a]
  listing = toListing list
  list = concat listing
  {-# MINIMAL list | listing #-}

-- | Takes a list of values @xs@ and transform it into a 'Listing' on which each
--   size is occupied by a single element from @xs@. 
--
-- To convert back to a list, just 'concat'.
toListing :: [a] -> [[a]]
toListing xs = map (:[]) xs

instance Listable () where
  list = [()]

instance Listable Int where
  list = [0,-1..] \/ [1..]

instance Listable Integer where
  list = [0,-1..] \/ [1..]

instance Listable Char where
  list = ['a'..'z']
      \/ [' ','\n']
      \/ ['A'..'Z']
      \/ ['0'..'9']
      \/ ['!'..'/']
      \/ ['\t']
      \/ [':'..'@']
      \/ ['['..'`']
      \/ ['{'..'~']

instance Listable Bool where
  listing = cons0 False \++/ cons0 True

instance Listable a => Listable (Maybe a) where
  listing = cons0 Nothing \++/ cons1 Just

instance (Listable a, Listable b) => Listable (Either a b) where
  listing = wcons1 0 Left \\// wcons1 0 Right

instance (Listable a, Listable b) => Listable (a,b) where
  listing = lsProduct listing listing

instance (Listable a, Listable b, Listable c) => Listable (a,b,c) where
  listing = lsProductWith (\x (y,z) -> (x,y,z)) listing listing

instance (Listable a, Listable b, Listable c, Listable d) =>
         Listable (a,b,c,d) where
  listing = lsProductWith (\x (y,z,w) -> (x,y,z,w)) listing listing

instance (Listable a, Listable b, Listable c, Listable d, Listable e) =>
         Listable (a,b,c,d,e) where
  listing = lsProductWith (\x (y,z,w,v) -> (x,y,z,w,v)) listing listing

instance (Listable a) => Listable [a] where
  listing = cons0 []
       \++/ cons2 (:)

-- The position of Infinity in the enumeration is arbitrary.
lsFractional :: Fractional a => [[a]]
lsFractional = lsProductWith (+) lsFractionalParts
                                 (lsmap (fromIntegral) (listing::[[Integer]]))
          \++/ [ [], [], [1/0], [-1/0] {- , [-0], [0/0] -} ]
  where lsFractionalParts :: Fractional a => [[a]]
        lsFractionalParts = [0]
                          : [ [fromIntegral a / fromIntegral b]
                            | b <- iterate (*2) 2, a <- [1::Integer,3..b] ]

-- Note that this instance ignores NaN's.
instance Listable Float where
  listing = lsFractional

instance Listable Double where
  listing = lsFractional


-- | 'map' over a listing
lsmap :: (a -> b) -> [[a]] -> [[b]]
lsmap = map . map

-- | 'filter' a listing
lsfilter :: (a -> Bool) -> [[a]] -> [[a]]
lsfilter f = map (filter f)

-- | 'concat' a listing
lsConcat :: [[ [[a]] ]] -> [[a]]
lsConcat = foldr (\+:/) [] . map (foldr (\++/) [])
  where xss \+:/ yss = xss \++/ ([]:yss)

-- | 'concatMap' a listing
lsConcatMap :: (a -> [[b]]) -> [[a]] -> [[b]]
lsConcatMap f = lsConcat . lsmap f


wcons0 :: Int -> a -> [[a]]
wcons0 w x = replicate w [] ++ [[x]]

wcons1 :: Listable a => Int -> (a -> b) -> [[b]]
wcons1 w f = replicate w [] ++ lsmap f listing

wcons2 :: (Listable a, Listable b) => Int -> (a -> b -> c) -> [[c]]
wcons2 w f = replicate w [] ++ lsmap (uncurry f) listing

wcons3 :: (Listable a, Listable b, Listable c)
       => Int -> (a -> b -> c -> d) -> [[d]]
wcons3 w f = replicate w [] ++ lsmap (uncurry3 f) listing

wcons4 :: (Listable a, Listable b, Listable c, Listable d)
       => Int -> (a -> b -> c -> d -> e) -> [[e]]
wcons4 w f = replicate w [] ++ lsmap (uncurry4 f) listing

wcons5 :: (Listable a, Listable b, Listable c, Listable d, Listable e)
       => Int -> (a -> b -> c -> d -> e -> f) -> [[f]]
wcons5 w f = replicate w [] ++ lsmap (uncurry5 f) listing

cons0 :: a -> [[a]]
cons0 = wcons0 0

cons1 :: Listable a => (a -> b) -> [[b]]
cons1 = wcons1 1

cons2 :: (Listable a, Listable b) => (a -> b -> c) -> [[c]]
cons2 = wcons2 1

cons3 :: (Listable a, Listable b, Listable c) => (a -> b -> c -> d) -> [[d]]
cons3 = wcons3 1

cons4 :: (Listable a, Listable b, Listable c, Listable d)
      => (a -> b -> c -> d -> e) -> [[e]]
cons4 = wcons4 1

cons5 :: (Listable a, Listable b, Listable c, Listable d, Listable e)
      => (a -> b -> c -> d -> e -> f) -> [[f]]
cons5 = wcons5 1


-- | Lazily interleaves two lists, switching between elements of the two.
--   Union/sum of the elements in the lists.
--
-- > [x,y,z] \/ [a,b,c] == [x,a,y,b,z,c]
(\/) :: [a] -> [a] -> [a]
[]     \/ ys     = ys
(x:xs) \/ ys     = x:(ys \/ xs)
infixr 5 \/

-- | Product of two lists.
--
-- > [x,y] >< [a,b] = [(x,a),(x,b),(y,a),(y,b)]
(><) :: [a] -> [b] -> [(a,b)]
[]     ><  _  = []
(x:xs) >< ys = map ((,) x) ys ++ xs >< ys

-- | Product of two lists by a given function.
productWith :: (a->b->c) -> [a] -> [b] -> [c]
productWith _ []     _   =  []
productWith f (x:xs) ys  =  map (f x) ys ++ productWith f xs ys

-- | 'zipwith\'' works similarly to 'zipWith', but takes neutral elements to
--   operate when one of the lists is exhausted, so, you don't loose elements.
--
-- > zipWith' f z e [x,y] [a,b,c,d] == [f x a, f y b, f z c, f z d]
--
-- > zipWith' f z e [x,y,z] [a] == [f x a, f y e, f z e]
--
-- > zipWith' (+) 0 0 [1,2,3] [1,2,3,4,5,6] == [2,4,6,4,5,6]
zipWith' :: (a->b->c) -> a -> b  -> [a] -> [b] -> [c]
zipWith' _ _  _  []     [] = []
zipWith' f _  zy xs     [] = map (`f` zy) xs
zipWith' f zx _  []     ys = map (f zx) ys
zipWith' f zx zy (x:xs) (y:ys) = f x y : zipWith' f zx zy xs ys

-- | Combine two listings by appending values of each increasing size.
(\++/) :: [[a]] -> [[a]] -> [[a]]
(\++/) = zipWith' (++) [] []

-- | Combine two listings by interleaving values of each increasing size.
(\\//) :: [[a]] -> [[a]] -> [[a]]
(\\//) = zipWith' (\/) [] []

-- | Take the product of two listings.
--
-- > lsProduct [[0]..] [[0]..]
-- > == [  [(0,0)]
-- >    ,  [(1,0),(0,1)]
-- >    ,  [(2,0),(1,1),(0,2)]
-- >    ,  [(3,0),(2,1),(1,2),(0,3)]
-- >    ...
-- >    ]
--
-- In terms of '(><)', 'lsProduct' is:
--
-- > lsProduct [xs] [ys] = [xs><ys]
-- > lsProduct [xs0,xs1] [ys0] = [xs0><ys0, xs1><ys0]
-- > lsProduct [xs0,xs1] [ys0,ys1] = [xs0><ys0, xs1><ys0++xs0><ys1, xs1><ys1]
-- > lsProduct [xs0,xs1,xs2] [ys0,ys1] =
-- >                           [ xs0 >< ys0
-- >                           , xs1 >< ys0 ++ xs0 >< ys1
-- >                           , xs2 >< ys0 ++ xs1 >< ys1
-- >                           ]
-- > lsProduct [xs0,xs1,xs2] [ys0,ys1,ys2] =
-- >                           [ xs0 >< ys0
-- >                           , xs1 >< ys0 ++ xs0 >< ys1
-- >                           , xs2 >< ys0 ++ xs1 >< ys1 ++ xs0 >< ys2
-- >                           , xs2 >< ys1 ++ xs1 >< ys2
-- >                           , xs2 >< ys2
-- >                           ]
-- > lsProduct ...
lsProduct :: [[a]] -> [[b]] -> [[(a,b)]]
lsProduct = lsProductWith (,)

-- | Infix shorthand for 'lsProduct'
(>++<) :: [[a]] -> [[b]] -> [[(a,b)]]
(>++<) = lsProduct

lsProductWith :: (a->b->c) -> [[a]] -> [[b]] -> [[c]]
lsProductWith _ _ [] = []
lsProductWith _ [] _ = []
lsProductWith f (xs:xss) yss = zs  :  zss \++/ lsProductWith f xss yss
  where (zs:zss) = map (productWith f xs) yss


class Testable a where
  lsResults   :: a -> [[Bool]]
  lsArguments :: a -> [[[String]]]

instance Testable Bool where
  lsResults   p = [[p]]
  lsArguments p = [[[]]]

instance (Testable b, Show a, Listable a) => Testable (a->b) where
  lsResults   p = lsConcatMap (lsResults . p) listing
  lsArguments p = lsConcatMap (\x -> (showsPrec 11 x "":) `lsmap` lsArguments (p x)) listing

-- List boolean results of a 'Testable' property.
results :: Testable a => a -> [Bool]
results = concat . lsResults

-- List string representations of arguments of a 'Testable' property.
arguments :: Testable a => a -> [[String]]
arguments = concat . lsArguments

-- List results and arguments of a 'Testable' property.
resultArguments :: Testable a => a -> [(Bool,[String])]
resultArguments p = zip (results p) (arguments p)


-- | Returns the list of all counterexamples for a given property.
counterExamples :: Testable a => Int -> a -> [[String]]
counterExamples n = map snd . filter (not . fst) . take n . resultArguments

-- | For a given property, returns 'Just' the string description of the first
--   counterexample or 'Nothing'.
counterExample :: Testable a => Int -> a -> Maybe [String]
counterExample n = listToMaybe . counterExamples n

-- | Returns the list of all witnesses for a given property.
witnesses :: Testable a => Int -> a -> [[String]]
witnesses n = map snd . filter (fst) . take n . resultArguments

-- | For a given property up to some values,
--   returns Just the first witness or Nothing.
witness :: Testable a => Int -> a -> Maybe [String]
witness n = listToMaybe . witnesses n

-- | Does a property __hold__ for a given number of test values?
--
-- > holds 1000 $ \xs -> length (sort xs) == length xs
holds :: Testable a => Int -> a -> Bool
holds n = and . take n . results

-- | Does a property __fail__ for a given number of test values?
--
-- > fails 1000 $ \xs -> xs ++ ys == ys ++ xs
fails :: Testable a => Int -> a -> Bool
fails n = not . holds n

-- | Check if there exists an assignment of values that makes the property true.
exists :: Testable a => Int -> a -> Bool
exists n = or . take n . results

uncurry3 :: (a->b->c->d) -> (a,b,c) -> d
uncurry3 f (x,y,z) = f x y z

uncurry4 :: (a->b->c->d->e) -> (a,b,c,d) -> e
uncurry4 f (x,y,z,w) = f x y z w

uncurry5 :: (a->b->c->d->e->f) -> (a,b,c,d,e) -> f
uncurry5 f (x,y,z,w,v) = f x y z w v

-- | Boolean implication.  Use this for defining conditional properties:
--
-- > prop_something x y = condition x y ==> something x y
(==>) :: Bool -> Bool -> Bool
False ==> _ = True
True  ==> p = p
infixr 0 ==>