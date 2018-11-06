-- |
-- Module      : Test.LeanCheck.Function.Listable
-- Copyright   : (c) 2015-2018 Rudy Matela
-- License     : 3-Clause BSD  (see the file LICENSE)
-- Maintainer  : Rudy Matela <rudy@matela.com.br>
--
-- This module is part of LeanCheck,
-- a simple enumerative property-based testing library.
--
-- This module exports a 'Listable' instance for functions.
--
-- LeanCheck provides several alternative definitions of 'Listable' functions:
--
-- * "Test.LeanCheck.Function.Listable.ListsOfPairs":
--   considers functions as a finite list of exceptional input-output cases to
--   a default value (list of pairs of arguments and results).
--   This is the LeanCheck default, and is the one exported by this module.
--
-- * "Test.LeanCheck.Function.Listable.CoListable":
--   declares a 'CoListable' typeclass similar to SmallCheck's @CoSerial@.
--   Currently a stub.
--
-- Take care: all the above 'Listable' instances are __experimental__.  Only
-- one of the above can be imported at a time.
--
-- Warning: this is only intended to be used in testing modules.  Avoid
-- importing this on modules that are used as libraries.
module Test.LeanCheck.Function.Listable () where

import Test.LeanCheck.Function.Listable.ListsOfPairs
