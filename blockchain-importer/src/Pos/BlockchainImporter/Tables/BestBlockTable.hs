{-# LANGUAGE Arrows #-}

module Pos.BlockchainImporter.Tables.BestBlockTable
  ( -- * Getters
    getBestBlock
    -- * Manipulation
  , updateBestBlock
  ) where

import           Universum

import qualified Control.Arrow as A
import           Data.Profunctor.Product.TH (makeAdaptorAndInstance)
import qualified Database.PostgreSQL.Simple as PGS
import           Opaleye
import           Opaleye.RunSelect

import           Pos.Core (BlockCount)

data BestBlockRowPoly a = BestBlockRow  { bbBlockNum :: a
                                        } deriving (Show)

type BestBlockRowPGW = BestBlockRowPoly (Column PGInt8)
type BestBlockRowPGR = BestBlockRowPoly (Column PGInt8)

$(makeAdaptorAndInstance "pBestBlock" ''BestBlockRowPoly)

bestBlockTable :: Table BestBlockRowPGW BestBlockRowPGR
bestBlockTable = Table "bestblock" (pBestBlock  BestBlockRow
                                                { bbBlockNum = required "best_block_num" })

-- | Updates the best block number stored
updateBestBlock :: BlockCount -> PGS.Connection -> IO ()
updateBestBlock newBestBlock conn = do
  n <- runUpdate_ conn $
                  Update bestBlockTable (const colBlockNum) (const $ pgBool True) rCount
  when (n == 0) $ void $ runInsert_ conn $
                                    Insert bestBlockTable [colBlockNum] rCount Nothing
    where colBlockNum = BestBlockRow $ pgInt8 $ fromIntegral newBestBlock

-- | Returns the best block number
getBestBlock :: PGS.Connection -> IO BlockCount
getBestBlock conn = do
  bestBlockMatched :: [Int64] <- runSelect conn bestBlockQuery
  case bestBlockMatched of
    [ bestBlockNum ] -> pure $ fromIntegral bestBlockNum
    _                -> pure 0
  where bestBlockQuery = proc () -> do
          BestBlockRow bestBlockNum <- (selectTable bestBlockTable) -< ()
          A.returnA -< bestBlockNum
