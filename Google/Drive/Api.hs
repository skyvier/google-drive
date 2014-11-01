module Network.Google.Drive.Api
    ( Api
    , Path
    , Params
    , runApi
    , logApi
    , logApiErr
    , simpleApi
    , getApi
    , postApi
    , authenticatedDownload

    -- Re-exports
    , liftIO
    ) where

import Control.Monad.Reader
import Data.Aeson (FromJSON(..), ToJSON(..), decode, encode)
import Data.ByteString (ByteString)
import Data.Conduit.Binary (sinkFile)
import Data.Monoid ((<>))
import Network.HTTP.Conduit
    ( Request(..)
    , RequestBody(..)
    , http
    , httpLbs
    , parseUrl
    , responseBody
    , setQueryString
    , withManager
    )
import Network.HTTP.Types (Header, Method, hAuthorization, hContentType)
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory)
import System.IO (hPutStrLn, stderr)

import qualified Data.ByteString.Char8 as C8
import qualified Data.ByteString.Lazy as BL
import qualified Data.Conduit as C

import Drync.Token

type Api a = ReaderT OAuth2Tokens IO a

runApi :: OAuth2Tokens -> Api a -> IO a
runApi tokens f = runReaderT f tokens

-- TODO: WriterT, async logging
logApi :: String -> Api ()
logApi = liftIO . putStrLn

-- TODO: WriterT, async logging
logApiErr :: String -> Api ()
logApiErr = liftIO . hPutStrLn stderr

type URL = String
type Path = String
type Params = [(ByteString, Maybe ByteString)]

baseUrl :: URL
baseUrl = "https://www.googleapis.com/drive/v2"

simpleApi :: FromJSON a => Path -> Api (Maybe a)
simpleApi path = getApi path []

getApi :: FromJSON a => Path -> Params -> Api (Maybe a)
getApi path query = do
    request <- fmap (setQueryString query) $ authorize =<< apiRequest path

    fmap (decode . responseBody) $ withManager $ httpLbs request

postApi :: (ToJSON a, FromJSON b) => Path -> a -> Api (Maybe b)
postApi path body = do
    let content = (hContentType, "application/json")
        modify = addHeader content . addBody (encode body) . setMethod "POST"

    request <- fmap modify $ authorize =<< apiRequest path

    fmap (decode . responseBody) $ withManager $ httpLbs request

authenticatedDownload :: URL -> FilePath -> Api ()
authenticatedDownload url path = do
    request <- authorize =<< (liftIO $ parseUrl url)

    liftIO $ createDirectoryIfMissing True $ takeDirectory path

    withManager $ \manager -> do
        response <- http request manager
        responseBody response C.$$+- sinkFile path

apiRequest :: Path -> Api Request
apiRequest path = liftIO $ parseUrl $ baseUrl <> path

authorize :: Request -> Api Request
authorize request = do
    tokens <- ask

    let authorization = C8.pack $ "Bearer " <> accessToken tokens

    return $ addHeader (hAuthorization, authorization) request

addHeader :: Header -> Request -> Request
addHeader header request =
    request { requestHeaders = header:requestHeaders request }

addBody :: BL.ByteString -> Request -> Request
addBody bs request = request { requestBody = RequestBodyLBS bs }

setMethod :: Method -> Request -> Request
setMethod method request = request { method = method }
