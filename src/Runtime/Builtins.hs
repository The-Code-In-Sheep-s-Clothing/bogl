-- | Language builtins/Prelude

module Runtime.Builtins where

import Language.Syntax
import Language.Types

import Runtime.Monad
import Runtime.Values

import qualified Data.Set as S
import Data.Array

import Data.Map (Map)
import qualified Data.Map as M

import Control.Monad.State

single x = Tup [x]
builtinT :: Xtype -> Xtype -> [(String, Type)]
builtinT = \inputT pieceT -> [
  ("input", Plain $ inputT),
  ("place", Function (Ft (Tup [pieceT, (X Board S.empty), (Tup [X Itype S.empty, X Itype S.empty])]) (X Board S.empty))),
  ("remove", Function (Ft (Tup [(X Board S.empty), (Tup [X Itype S.empty, X Itype S.empty])]) (X Board S.empty))),
  ("countBoard", Function (Ft (Tup [pieceT, (X Board S.empty)]) (X Itype S.empty))),
  ("countCol", Function (Ft (Tup [pieceT, (X Board S.empty)]) (X Itype S.empty))),
  ("countRow", Function (Ft (Tup [pieceT, (X Board S.empty)]) (X Itype S.empty))),
  ("countDiag", Function (Ft (Tup [pieceT, (X Board S.empty)]) (X Itype S.empty))),
  ("isFull", Function (Ft (single (X Board S.empty)) (X Booltype S.empty))),
  ("inARow", Function (Ft (Tup [X Itype S.empty, pieceT, X Board S.empty]) (X Booltype S.empty))),
  ("next", Function (Ft (single (X Top (S.fromList ["X", "O"]))) (X Top (S.fromList ["X", "O"])))),
  ("not", Function (Ft (single (X Booltype S.empty)) (X Booltype S.empty))),
  ("or", Function (Ft (Tup [X Booltype S.empty, X Booltype S.empty]) (X Booltype S.empty))),
  ("and", Function (Ft (Tup [X Booltype S.empty, X Booltype S.empty]) (X Booltype S.empty))),
  ("less", Function (Ft (Tup [X Itype S.empty, X Itype S.empty]) (X Booltype S.empty)))
           ]

-- | places a piece on a board and also adds this new board to the display buffer.
--   We only want the latest version of each unique board, so filter out its predecessor.
place :: [Val] -> Eval Val
place = \[v, Vboard arr, Vt [Vi x, Vi y]] -> do
   let b = Vboard $ arr // [((x,y), v)]
   (tape, boards) <- get
   put (tape, filter (/= Vboard arr) boards ++ [b])
   return b

builtins :: [(Name, [Val] -> Eval Val)]
builtins = [
  ("place", place),
  ("remove", \[Vboard arr, Vt [Vi x, Vi y]] -> return $ Vboard $ arr // pure ((x,y), Vs "Empty")),
  ("countBoard", \[v, Vboard arr] -> return $ Vi $ length $ filter (== v) (elems arr)),
  ("countCol", \[v, Vboard arr] -> return $ Vi $ countCol arr v),
  ("countRow", \[v, Vboard arr] -> return $ Vi $ countRow arr v),
  ("countDiag", \[v, Vboard arr] -> return $ Vi $ countDiag arr v),
  ("isFull", \[Vboard arr] -> return $ Vb $ all (/= Vs "Empty") $ elems arr),
  ("inARow", \[Vi i, v, Vboard arr] -> return $ Vb $ inARow arr v i),
  ("next", \[Vs s] -> return $ if s == "X" then Vs "O" else Vs "X"),
  ("not", \[Vb b] -> return $ Vb (not b)),
  ("or", \[Vb a, Vb b] -> return $ Vb (a || b)),
  ("and", \[Vb a, Vb b] -> return $ Vb (a && b)),
  ("less", \[Vi n, Vi m] -> return $ Vb (n < m))
  ]

builtinRefs :: [(Name, Eval Val)]
builtinRefs = [
   ("input", readTape)
   ]

-- the count of adjacent cells in four directions (above, diagonal @ 10:30, left, diagonal @ 7:30)
type Count = (Int, Int, Int, Int)
type CountMap = M.Map (Int, Int) Count

-- | A safe map lookup function which returns a default value for keys not in the map
peek :: (Int, Int) -> CountMap -> Count
peek p m = case M.lookup p m of
               Nothing   -> (0,0,0,0)
               (Just c)  -> c

addCell :: (Int, Int) -> CountMap -> CountMap
addCell p@(x,y) m = M.insert p (top + 1, tdiag + 1, left + 1, bdiag + 1) m
   where
      (top,_,_,_)   = peek (x, y - 1) m
      (_,tdiag,_,_) = peek (x - 1, y - 1) m
      (_,_,left,_)  = peek (x - 1, y) m
      (_,_,_,bdiag) = peek (x - 1, y + 1) m

checkCell :: Val -> ((Int, Int), Val) -> CountMap -> CountMap
checkCell v (p,v') m = if v == v' then addCell p m else m

-- scans cells downwards by column (the order given by (assocs b) with (x,y) coords)
-- each cell's count is the increment of the counts of the four cells before it
checkCells :: Board -> Val -> [Int]
checkCells b v = maxCount
   where
      maxCount = foldr (\c acc -> update c acc) [0,0,0,0] counts
      update (t,td,l,bd) r = zipWith max [t,td,l,bd] r
      counts = M.elems processedBoard
      processedBoard = foldl (\m c -> checkCell v c m) M.empty (assocs b)

countCol, countRow, countDiag :: Board -> Val -> Int
countCol b v = checkCells b v !! 0
countRow b v = checkCells b v !! 2
countDiag b v = max (checkCells b v !! 1) (checkCells b v !! 3)

-- | checks whether a board has i cells containing v in a row
inARow :: Board -> Val -> Int -> Bool
inARow b v i = maximum (checkCells b v) >= i
