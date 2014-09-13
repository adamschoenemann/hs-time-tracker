module TimeTrackerTypes where
import Database.HDBC
import Database.HDBC.Sqlite3
import Control.Monad
import Control.Monad.Trans
import Control.Monad.Writer
import Control.Monad.Reader
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

--instance Monoid NominalDiffTime where
--	mappend a b = a + b
--	mzero = fromInteger 0 :: NominalDiffTime

isEnded :: Session -> Bool
isEnded s = not $ (sessEnd s) == Nothing

sessDuration :: Session -> Maybe NominalDiffTime
sessDuration sess = case end of
	Nothing -> Nothing
	Just endTime -> Just $ diffUTCTime endTime startTime
	where
		end = sessEnd sess
		startTime = sessStart sess


taskFromSql :: [SqlValue] -> Task
taskFromSql [id, name] = Task (fromSql id) (fromSql name)

sessionFromSql :: [SqlValue] -> Task -> Session
sessionFromSql [id, _, start, end] task = Session (fromSql id) task (fromSql start) (fromSql end)

type TrackerMonad a = ReaderT Connection (WriterT [String] IO) a

runTrackerMonad :: TrackerMonad a -> Connection -> IO (a, [String])
runTrackerMonad m conn = runWriterT $ runReaderT m conn