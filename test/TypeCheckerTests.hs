module TypeCheckerTests where

--
-- TypeChecker Tests
--

import Test.HUnit
import Parser.Parser
import Language.Types
import qualified Data.Set as S
import Data.Either
import Utils
import Typechecker.Typechecker
import Language.Syntax
import Typechecker.Monad
import System.Directory
import System.FilePath

import Text.Parsec
import Text.Parsec.Error
import Text.Parsec.Pos

--
-- exported tests for the TypeChecker
--
typeCheckerTests :: Test
typeCheckerTests = TestList
   [
    testSmallLiteralBoardEq
   ,testLargeLiteralBoardEq
   ,testOutOfBoundsLiteralGet
   ]

-- | Represents the rest result for typchecking examples
-- On Fail, return # failures & # errors for easier analysis in the cmd line
data TypeCheckerTestResult =
  Fail Int Int |
  Pass

-- | Allows displaying of a typechecker example checking result
instance Show TypeCheckerTestResult where
  show (Fail fails errs) = "Typechecking all Examples\n Failures: " ++ show fails ++ " Errors: " ++ show errs
  show Pass              = "TypeChecking all Examples\n Failures: 0 Errors: 0\n (Passed)"


-- | Determines whether a type checker result is passing or not
tcPassed :: TypeCheckerTestResult -> Bool
tcPassed (Fail _ _) = False
tcPassed Pass       = True

--
-- TEST STRUCTURE
--
-- testNameOfTest :: Test
-- testNameOfTest = TestCase (
--  assertEqual "Test Description"
--  ExpectedValue
--  ExpressionToCheck)
--

-- | A dummy position with which to annotate test cases
dummyPos :: SourcePos
dummyPos = initialPos ""

-- | Check that every Game in a list type checks
allPassTC :: [Game SourcePos] -> Bool
allPassTC = and . map success . map tc

-- | Check that every Game in a list fails to type check
allFailTC :: [Game SourcePos] -> Bool
allFailTC = and . map (not . success) . map tc

-- | Check that every Expr in a list fails to type check
allFailTCexpr :: Env -> [Expr SourcePos] -> Bool
allFailTCexpr = \e -> and . map isLeft . map (tcexpr e)

testOutOfBoundsLiteralGet :: Test
testOutOfBoundsLiteralGet = TestCase (
   assertBool "board access with integer literal that is out of bounds type checks" $
   allFailTCexpr env [nx, ny, zx, zy, gx, gy]
   )
   where
      env = exampleEnv { types = ("b", boardt) : types exampleEnv }
      get = \(x, y) -> Binop Get (Ref "b") (Tuple [I x, I y])
      nx = get (-1, 1)
      ny = get (1, -1)
      zx = get (0, 1)
      zy = get (1, 0)
      (mx, my) = Typechecker.Monad.size exampleEnv
      gx = get (mx + 1, 1)
      gy = get (mx, my + 1)

testSmallLiteralBoardEq :: Test
testSmallLiteralBoardEq = TestCase (
   assertBool "BoardEq with integer literal that is <= 0 type checks" $
   allFailTC (map (testGame . \x -> [x]) [z, n, n2])
   )
   where
     z = BVal (Sig "b1" (Plain boardxt)) [PosDef "b1" (Index 0) (Index 0) (I 1)] dummyPos
     n  = BVal (Sig "b1" (Plain boardxt)) [PosDef "bn" (Index (-1)) (ForAll "y") (I 1)] dummyPos
     n2 = BVal (Sig "b1" (Plain boardxt)) [PosDef "bn" (ForAll ("x")) (Index (-10)) (I 1)] dummyPos

testLargeLiteralBoardEq :: Test
testLargeLiteralBoardEq = TestCase (
   assertBool "BoardEq with integer literal that is greater than board size type checks" $
   allFailTC (map (testGame . \x -> [x]) [a, b])
   )
   where
     a = BVal (Sig "b1" (Plain boardxt)) [PosDef "b1" (Index 10) (Index 1) (I 1)] dummyPos
     b = BVal (Sig "b1" (Plain boardxt)) [PosDef "b1" (Index 1) (Index 10) (I 1)] dummyPos

typeCheckAllExamples :: IO TypeCheckerTestResult
typeCheckAllExamples = do
   bglFiles <- getExampleFiles
   logTestStmt "Type checking:"
   mapM_ (putStrLn . ("\t" ++)) bglFiles
   results <- mapM parseGameFile bglFiles
   let parsed = rights results           -- the parser tests report these failures
       failures = filter (not . success) $ map tc parsed
       errs = map Typechecker.Typechecker.errors failures
   logTestStmt "Failures:"
   mapM_ (putStrLn . ("\n" ++)) (map showTCError (concat errs))
   let errCount = length errs
   let failCount= length failures
   return $ if errCount > 0 || failCount > 0 then (Fail failCount errCount) else Pass

illTypedPath :: String
illTypedPath = examplesPath ++ "illTyped/"

illTypedFiles :: IO [String]
illTypedFiles = do
   files  <- listDirectory illTypedPath
   let fullPaths = (map ((++) illTypedPath) files)
       bglFiles  = filter (isExtensionOf ".bgl") (fullPaths)
   return bglFiles

typeCheckIll :: IO Int
typeCheckIll = do
   bglFiles <- illTypedFiles
   logTestStmt "Type checking (ill typed):"
   mapM_ (putStrLn . ("\t" ++)) bglFiles
   results <- mapM parseGameFile bglFiles
   let parsed = zip bglFiles $ rights results -- assume they all parsed correctly
       succs  = filter (success . snd) $ map (\p -> (fst p, (tc . snd) p)) parsed
   logTestStmt "Incorrect successes:"
   mapM_ (putStrLn . ("\t" ++)) $ map (\p -> fst p ++ "\n\t\t" ++ (show (((rtypes . snd) p)))) succs
   return $ length succs