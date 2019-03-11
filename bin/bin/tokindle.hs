#!/usr/bin/env stack
-- stack script --resolver lts-13.12 --package "process directory temporary split"

import           Control.Monad      (void)
import           Data.Char          (isSpace)
import           Data.List.Split    (splitOn)
import           Data.Semigroup     ((<>))
import           System.Environment (getArgs)
import           System.IO.Temp     (withSystemTempDirectory)
import           System.Process     (callProcess, readProcess)


mailFile :: String -> String -> IO ()
mailFile file title = do
  recipient <- takeWhile (not . isSpace) <$>
    readProcess "khard" ["email", "-p", "--remove-first-line", "kindle"] ""
  let
    muttArgs = ["-a", file, "-s", title, "--", recipient]
  void $ readProcess "mutt" muttArgs "Have fun reading"


sendPageToKindle :: String -> String -> IO ()
sendPageToKindle url tmpDir = do
    let
      ext = last $ splitOn "." url
    case ext of
      "epub" -> processEpub
      "pdf"  -> processPdf
      _      -> processPage
    where
      title = head $ splitOn "?" $ last (filter (not . null) (splitOn "/" url))
      epub = tmpDir <> title <> ".epub"
      mobi = tmpDir <> title <> ".mobi"
      pdf = tmpDir <> title <> ".pdf"
      pdfProcessed = tmpDir <> title <> "k2opt.pdf"
      processPage = do
        callProcess "pandoc" [url, "-t", "epub", "--output", epub]
        callProcess "ebook-convert" [epub, mobi]
        mailFile mobi title
      processEpub = do
        callProcess "curl" [url, "--output", epub]
        callProcess "ebook-convert" [epub, mobi]
        mailFile mobi title
      processPdf = do
        callProcess "curl" [url, "--output", pdf]
        callProcess "k2pdfopt"
          [ "-dev", "kp3"
          , "-vls"
          , "-3"
          , "-o", pdfProcessed
          , "-vb", "1.25"
          , pdf ]
        mailFile pdfProcessed title


main :: IO ()
main = do
  [url] <- getArgs
  withSystemTempDirectory "kindle" (sendPageToKindle url)
