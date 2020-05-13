--
-- ReadFile.hs
--
-- API Endpoint that allows reading a .bgl file
--

module API.ReadFile (handleReadFile) where

import API.JSONData
import Servant
import Control.Exception hiding (Handler)
import Control.Monad.IO.Class

-- | handles reading a file and returning it's
-- contents to the requester
handleReadFile :: SpielRead -> Handler SpielFile
handleReadFile rf = do
  (liftIO (_handleReadFile rf))


-- internally attempts to read and return a file
_handleReadFile :: SpielRead -> IO SpielFile
_handleReadFile (SpielRead fn) = do
  result <- try $ readFile (fn) :: IO (Either IOException String)
  case result of
    Right contents  -> return (SpielFile fn contents)
    Left _          -> return (SpielFile "0" ("Couldn't find file '" ++ fn ++ "' to read from!"))
