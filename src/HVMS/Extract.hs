module HVMS.Extract where

import Data.Word
import HVMS.Type

-- Term to Core
-- ------------

extractPCore :: Term -> IO PCore
extractPCore term = case termTag term of
  NUL -> return PNul
  VAR -> do
    got <- get (termLoc term)
    extractVar (termLoc term) got
  LAM -> do
    let loc = termLoc term
    var <- get (loc + 0)
    bod <- get (loc + 1)
    var' <- extractNCore (loc + 0) var
    bod' <- extractPCore bod
    return $ PLam var' bod'
  SUP -> do
    let loc = termLoc term
    tm1 <- get (loc + 0)
    tm2 <- get (loc + 1)
    tm1' <- extractPCore tm1
    tm2' <- extractPCore tm2
    return $ PSup tm1' tm2'
  W32 -> return $ PU32 (termLoc term)

-- Convert a term in memory to a NCore.
-- The optional location is the location of the term
-- being extracted in the buffer.
extractNCore :: Loc -> Term -> IO NCore
extractNCore loc term = case termTag term of
  ERA -> return NEra
  SUB -> return $ NSub ("v" ++ show loc)
  APP -> do
    let loc = termLoc term
    arg <- get (loc + 0)
    ret <- get (loc + 1)
    arg' <- extractPCore arg
    ret' <- extractNCore (loc + 1) ret
    return $ NApp arg' ret'
  DUP -> do
    let loc = termLoc term
    dp1 <- get (loc + 0)
    dp2 <- get (loc + 1)
    dp1' <- extractNCore (loc + 0) dp1
    dp2' <- extractNCore (loc + 1) dp2
    return $ NDup dp1' dp2'
  x | elem x [OPX, OPY] -> do
    let op  = termOper term
    let loc = termLoc term
    arg <- get (loc + 0)
    ret <- get (loc + 1)
    arg' <- extractPCore arg
    ret' <- extractNCore (loc + 1) ret
    return $ NOp2 op arg' ret'

extractVar :: Loc -> Term -> IO PCore
extractVar loc term = case termTag term of
  VAR -> extractPCore term
  NUL -> extractPCore term
  LAM -> extractPCore term
  SUP -> extractPCore term
  SUB -> return $ PVar ("v" ++ show loc)
  W32 -> return $ PU32 (termLoc term)

-- Bag and Net Extraction
-- ---------------------

extractDex :: Loc -> IO Dex
extractDex loc = do
  neg  <- get (loc + 0)
  pos  <- get (loc + 1)
  neg' <- extractNCore (loc + 0) neg
  pos' <- extractPCore pos
  return (neg', pos')

extractBag :: [Loc] -> IO Bag
extractBag [] = return []
extractBag (loc:locs) = do
  dex  <- extractDex loc
  dexs <- extractBag locs
  return (dex : dexs)

extractNet :: Term -> IO Net
extractNet root = do
  root' <- extractPCore root
  ini   <- rbagIni
  end   <- rbagEnd
  bag   <- extractBag [ini, ini+2..end-2]
  return $ Net root' bag

-- Main Entry Points
-- ----------------

doExtractNet :: Term -> IO Net
doExtractNet root = extractNet root
