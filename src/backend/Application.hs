module Application
       ( appMain
       , develMain
       ) where

import Control.Concurrent (forkIO)
import Control.Monad.Logger (runLoggingT)
import Database.Persist.Postgresql
import System.Environment (lookupEnv)
import System.Log.FastLogger (defaultBufSize, newStdoutLoggerSet)
import Yesod
import Yesod.Default.Config2 (makeYesodLogger)
import Data.Monoid ((<>))
import qualified Data.ByteString.Char8 as BS
import qualified Watcher as EW
import Foundation
import Model
import Handler

mkYesodDispatch "App" resourcesApp

appMain :: IO ()
appMain = do
    port <- lookupEnv "PORT" >>= return . maybe 3000 read
    dbConnString <- lookupEnv "DATABASE_URL" >>= return . maybe "postgresql://localhost/poc-yesod-elm" BS.pack
    appLogger <- newStdoutLoggerSet defaultBufSize >>= makeYesodLogger
    let appStatic = embeddedStatic
        mkFoundation appConnPool = App {..}
        tmpFoundation = mkFoundation $ error "fake connection pool"
        logFunc = messageLoggerSource tmpFoundation appLogger
    pool <- flip runLoggingT logFunc $ createPostgresqlPool dbConnString 10
    runLoggingT (runSqlPool (runMigration migrateAll) pool) logFunc
    warp port $ mkFoundation pool

develMain :: IO ()
develMain = do
    mapM_ (forkIO . EW.watchWithConfig . createWatcherConfig) [("Public", "app"), ("Admin", "admin")]
    appMain
    where
        createWatcherConfig (input, output) = EW.WatchConfig
            { watchDir = "src/frontend"
            , compileFile = input <> ".elm"
            , outputDir = "src/static/" <> output <> ".js"
            }
