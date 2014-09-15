module TimeTrackerTypes where
import Database.HDBC
import Database.HDBC.Sqlite3
import Control.Monad
import Control.Monad.Trans
import Control.Monad.Writer
import Control.Monad.Reader
import Control.Monad.Error
import Data.Time
import System.Locale
import System.Time.Utils (renderSecs)
import Data.Monoid

data Task = Task {
     taskId :: Integer
    ,taskName :: String
} deriving (Show)

data Session = Session {
     sessId :: Integer
    ,sessTask :: Task
    ,sessStart :: UTCTime
    ,sessEnd :: Maybe UTCTime
} deriving (Show)

data TTError = NoTaskFound String
             | NoSessionFound String
             | UnexpectedSqlResult String
             | TaskAlreadyExists String
             | OtherSessionStarted String
             | OtherError String
             deriving (Show)

instance Error TTError where
    noMsg = OtherError "An error occured"
    strMsg s = OtherError s

unwrapTTError :: TTError -> String
unwrapTTError err@(NoTaskFound s) = s
unwrapTTError err@(NoSessionFound s) = s
unwrapTTError err@(UnexpectedSqlResult s) = show err
unwrapTTError err@(TaskAlreadyExists s) = s
unwrapTTError err@(OtherSessionStarted s) = s
unwrapTTError err@(OtherError s) = show err


isEnded :: Session -> Bool
isEnded s = not $ (sessEnd s) == Nothing

-- TODO: Implement this with adding the time to sessStart
--setSessDuration :: Session -> NominalDiffTime -> Session
--setSessDuration s dur =

sessDuration :: Session -> Maybe NominalDiffTime
sessDuration sess = case end of
    Nothing -> Nothing
    Just endTime -> Just $ diffUTCTime endTime startTime
    where
        end = sessEnd sess
        startTime = sessStart sess

sessDurationMonad :: Session -> IO NominalDiffTime
sessDurationMonad sess = do
    let dur = sessDuration sess
    case dur of
        Just x -> return x
        Nothing -> do
            cur <- getCurrentTime
            return $ diffUTCTime cur (sessStart sess)



taskFromSql :: [SqlValue] -> Task
taskFromSql [id, name] = Task (fromSql id) (fromSql name)

sessionFromSql :: [SqlValue] -> Task -> Session
sessionFromSql [id, _, start, end] task = Session (fromSql id) task (fromSql start) (fromSql end)

type TrackerMonad a = WriterT [String] (ReaderT Connection (ErrorT TTError IO)) a

runTrackerMonad :: TrackerMonad a -> Connection -> IO (Either TTError (a, [String]))
runTrackerMonad m conn = runErrorT (runReaderT (runWriterT m) conn)