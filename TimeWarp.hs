#!/usr/bin/env nix-shell
#! nix-shell -j 4 -i runhaskell -p 'pkgs.haskellPackages.ghcWithPackages (hp: with hp; [ turtle cassava vector safe yaml ])'
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/f2c4af4e3bd9ecd4b1cf494270eae5fd3ca9e68c.tar.gz

{-# LANGUAGE OverloadedStrings, RecordWildCards #-}

import Control.Monad (forM_)
import Data.Monoid ((<>))
import Data.Yaml (decodeFile)
import Filesystem.Path.CurrentOS (encodeString)
import GHC.Conc (threadDelay)
import Prelude hiding (FilePath)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Turtle

import NixOps


data Command =
    Deploy
  | Destroy
  | FromScratch
  | CheckStatus
  | RunExperiment
  | Build
  deriving (Show)

subparser :: Parser Command
subparser =
      subcommand "deploy" "Deploy the whole cluster" (pure Deploy)
  <|> subcommand "destroy" "Destroy the whole cluster" (pure Destroy)
  <|> subcommand "build" "Build the application" (pure Build)
  <|> subcommand "fromscratch" "Destroy, Delete, Create, Deploy" (pure FromScratch)
  <|> subcommand "checkstatus" "Check if nodes are accessible via ssh and reboot if they timeout" (pure CheckStatus)
  <|> subcommand "runexperiment" "Deploy cluster and perform measurements" (pure RunExperiment)


parser :: Parser (Options, Command)
parser = (,) <$> optionsParser
             <*> subparser


args = " -d time-warp" <> nixpath
nixpath = " -I ~/ "
deployment = " deployments/timewarp.nix "


main :: IO ()
main = do
  (opts@Options{..}, command) <- options "Helper CLI around NixOps to run experiments" parser
  Just c <- decodeFile $ encodeString oConfigFile
  case command of
    Deploy        -> deploy        opts c
    Destroy       -> destroy       opts c
    FromScratch   -> fromscratch   opts c
    CheckStatus   -> checkstatus        c
    RunExperiment -> runexperiment      c
    Build         -> build c
    -- TODO: invoke nixops with passed parameters

runexperiment :: NixOpsConfig -> IO ()
runexperiment c = do
  -- build
  --checkstatus
  --deploy
  sshForEach c "systemctl stop timewarp"
  sshForEach c "rm -f /home/timewarp/node.log"
  nodes <- getNodeNames c
  sshForEach c "systemctl start timewarp"
  threadDelay (150*1000000)
  dt <- dumpLogs c False nodes
  TIO.putStrLn $ "Log dir: tw_experiments/" <> dt

build :: NixOpsConfig -> IO ()
build c = do
  echo "Building derivation..."
  shells ("nix-build -j 4 --cores 2 tw-sketch.nix" <> nixPath c) empty

dumpLogs :: NixOpsConfig -> Bool ->  [NodeName] -> IO Text
dumpLogs c withProf nodes = do
    TIO.putStrLn $ "WithProf: " <> T.pack (show withProf)
    when withProf $ do
        echo "Stopping nodes..."
        sshForEach c "systemctl stop timewarp"
        sleep 2
        echo "Dumping logs..."
    (_, dt) <- fmap T.strip <$> shellStrict "date +%F_%H%M%S" empty
    let workDir = "tw_experiments/" <> dt
    TIO.putStrLn workDir
    shell ("mkdir -p " <> workDir) empty
    parallelIO $ fmap (dump workDir) nodes 
    return dt
  where
    dump workDir node = do
        forM_ logs $ \(rpath, fname) -> do
          scpFromNode c node rpath (workDir <> "/" <> fname (getNodeName node))
    logs = mconcat
             [ if withProf
                  then profLogs
                  else []
             , defLogs
             ]
defLogs =
    [ ("/home/timewarp/node.log", (<> ".log"))
    , ("/var/log/saALL", (<> ".sar"))
    ]
profLogs =
    [ 
    --  ("/var/lib/cardano-node/cardano-node.prof", (<> ".prof"))
    --, ("/var/lib/cardano-node/cardano-node.hp", (<> ".hp"))
    ---- in fact, if there's a heap profile then there's no eventlog and vice versa
    ---- but scp will just say "not found" and it's all good
    --, ("/var/lib/cardano-node/cardano-node.eventlog", (<> ".eventlog"))
    ]
