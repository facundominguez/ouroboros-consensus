{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeApplications  #-}

{-# OPTIONS_GHC -Wno-orphans #-}

-- | 'StrictMVar's with 'NoThunks' invariants.
--
-- Custom invariants can still be specified in addition to the default
-- 'NoThunks' invariant. See 'newMVarWithInvariant' and
-- 'newEmptyMVarWithInvariant'.
--
-- Use the @checkmvarinvariants@ cabal flag to enable or disable invariant
-- checks at compile time.
--
-- The exports of this module (should) mirror the exports of the
-- "Control.Concurrent.Class.MonadMVar.Strict.Checked.Switch" module from the
-- @strict-checked-vars@ package.
module Ouroboros.Consensus.Util.NormalForm.StrictMVar (
    -- * StrictMVar
    LazyMVar
  , StrictMVar
  , castStrictMVar
  , fromLazyMVar
  , isEmptyMVar
  , modifyMVar
  , modifyMVarMasked
  , modifyMVarMasked_
  , modifyMVar_
  , newEmptyMVar
  , newEmptyMVarWithInvariant
  , newMVar
  , newMVarWithInvariant
  , putMVar
  , readMVar
  , swapMVar
  , takeMVar
  , toLazyMVar
  , tryPutMVar
  , tryReadMVar
  , tryTakeMVar
  , withMVar
  , withMVarMasked
    -- * Invariant
  , checkInvariant
  , noThunksInvariant
    -- * Re-exports
  , MonadMVar
  ) where

import           Control.Concurrent.Class.MonadMVar (MonadInspectMVar (..))
import           Control.Concurrent.Class.MonadMVar.Strict.Checked.Switch hiding
                     (newEmptyMVar, newEmptyMVarWithInvariant, newMVar,
                     newMVarWithInvariant)
import qualified Control.Concurrent.Class.MonadMVar.Strict.Checked.Switch as Switch
import           Data.Proxy (Proxy (..))
import           GHC.Stack (HasCallStack)
import           NoThunks.Class (NoThunks (..), unsafeNoThunks)

{-------------------------------------------------------------------------------
  StrictMVar
-------------------------------------------------------------------------------}

-- | Create a 'StrictMVar' with a 'NoThunks' invariant.
newMVar :: (HasCallStack, MonadMVar m, NoThunks a) => a -> m (StrictMVar m a)
newMVar = Switch.newMVarWithInvariant noThunksInvariant

-- | Create an empty 'StrictMVar' with a 'NoThunks' invariant.
newEmptyMVar :: (MonadMVar m, NoThunks a) => m (StrictMVar m a)
newEmptyMVar = Switch.newEmptyMVarWithInvariant noThunksInvariant

-- | Create a 'StrictMVar' with a custom invariant /and/ a 'NoThunks' invariant.
--
-- When both the custom and 'NoThunks' invariants are broken, only the error
-- related to the custom invariant is reported.
newMVarWithInvariant ::
     (HasCallStack, MonadMVar m, NoThunks a)
  => (a -> Maybe String)
  -> a
  -> m (StrictMVar m a)
newMVarWithInvariant inv =
    Switch.newMVarWithInvariant (\x -> inv x <> noThunksInvariant x)

-- | Create an empty 'StrictMVar' with a custom invariant /and/ a 'NoThunks'
-- invariant.
--
-- When both the custom and 'NoThunks' invariants are broken, only the error
-- related to the custom invariant is reported.
newEmptyMVarWithInvariant ::
     (MonadMVar m, NoThunks a)
  => (a -> Maybe String)
  -> m (StrictMVar m a)
newEmptyMVarWithInvariant inv =
    Switch.newEmptyMVarWithInvariant (\x -> inv x <> noThunksInvariant x)

{-------------------------------------------------------------------------------
  Invariant
-------------------------------------------------------------------------------}

noThunksInvariant :: NoThunks a => a -> Maybe String
noThunksInvariant = fmap show . unsafeNoThunks

{-------------------------------------------------------------------------------
  NoThunks instance
-------------------------------------------------------------------------------}

instance NoThunks a => NoThunks (StrictMVar IO a) where
  showTypeOf _ = "StrictMVar IO"
  wNoThunks ctxt mvar = do
      aMay <- inspectMVar (Proxy @IO) (toLazyMVar mvar)
      noThunks ctxt aMay
