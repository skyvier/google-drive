{-# LANGUAGE OverloadedStrings #-}
module Network.Google.Drive.SearchSpec
    ( main
    , spec
    ) where

import SpecHelper

import Data.Text (Text)

main :: IO ()
main = hspec spec

spec :: Spec
spec = describe "Network.Google.Drive.Search" $ do
    it "can list files based on a query" $ do
        now <- getCurrentTime

        runApiSpec $ \folder -> do
            mapM_ createFile
                [ setParent folder $ newFile "test-file-1" now
                , setParent folder $ newFile "test-file-2" now
                , setParent folder $ newFile "test-file-3" now
                , setParent folder $ newFile "test-file-4" now
                ]

            files <- listFiles $
                fileId folder `qIn` Parents `qAnd`
                    (Title ?= ("test-file-1" :: Text) `qOr`
                     Title ?= ("test-file-3" :: Text))

            let titles = map (fileTitle . fileData) files
            titles `shouldSatisfy` ((== 2) . length)
            titles `shouldSatisfy` ("test-file-1" `elem`)
            titles `shouldSatisfy` ("test-file-3" `elem`)