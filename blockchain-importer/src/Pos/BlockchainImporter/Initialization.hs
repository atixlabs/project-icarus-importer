module Pos.BlockchainImporter.Initialization
  ( -- * Initialization functions
  initializePostgresDB
  ) where

import           Universum

import           Control.Lens (_Wrapped)
import           Data.Map ((\\))
import           Formatting (build, int, sformat, (%))
import           JsonLog (CanJsonLog (..))
import           System.Wlog (logInfo, logWarning)

import           Pos.Block.Logic (BypassSecurityCheck (..), MonadBlockApply, rollbackBlocksUnsafe)
import           Pos.Block.Slog (ShouldCallBListener (..))
import           Pos.Block.Types (Blund)
import           Pos.BlockchainImporter.Configuration (HasPostGresDB, postGreOperate)
import qualified Pos.BlockchainImporter.Tables.BestBlockTable as BestBlockT
import qualified Pos.BlockchainImporter.Tables.TxsTable as TxsT
import qualified Pos.BlockchainImporter.Tables.UtxosTable as UtxosT
import           Pos.Core (BlockCount, HasConfiguration, HasGeneratedSecrets,
                           HasGenesisBlockVersionData, HasGenesisData, HasProtocolConstants,
                           blkSecurityParam, difficultyL, epochIndexL, getChainDifficulty)
import qualified Pos.DB.Block.Load as DB
import qualified Pos.DB.BlockIndex as DB
import           Pos.Ssc.Configuration (HasSscConfiguration)
import           Pos.StateLock (Priority (..), StateLock, StateLockMetrics, withStateLock)
import           Pos.Txp (Utxo, genesisUtxo, unGenesisUtxo, utxoToModifier)
import           Pos.Txp.DB (getAllPotentiallyHugeUtxo)
import           Pos.Util.Chrono (NewestFirst, _NewestFirst)
import           Pos.Util.JsonLog.Events (MemPoolModifyReason (..))
import           Pos.Util.Util (HasLens')

-- FIXME: Remove things not needed from here
type InitializationMode ctx m =
  ( MonadBlockApply ctx m
  , CanJsonLog m
  , HasLens' ctx StateLock
  , HasLens' ctx (StateLockMetrics MemPoolModifyReason)
  , HasConfiguration
  , HasPostGresDB
  , HasGeneratedSecrets
  , HasGenesisData
  , HasProtocolConstants
  , HasGenesisBlockVersionData
  )

-- If this is the first time the importer was started, save the genesis utxos to the postgres db
initializePostgresDB :: InitializationMode ctx m => m ()
initializePostgresDB = do
  postgresUtxos <- liftIO $ postGreOperate $ UtxosT.getUtxos
  let genesisUtxos = unGenesisUtxo genesisUtxo
  when (null postgresUtxos) $
    postgresUtxos $ liftIO $ postGreOperate $ UtxosT.applyModifierToUtxos $ utxoToModifier
  logInfo "Initialized postgres db"
