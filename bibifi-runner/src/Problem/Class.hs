module Problem.Class where

import Cloud
import Common
import Core.DatabaseM
import qualified Data.Aeson as Aeson
import Database.Persist
import Git
import Model
import qualified Network.HTTP.Conduit as HTTP

data RunnerOptions = RunnerOptions {
        runnerRepositoryPath :: FilePath
      , runnerCloudConfiguration :: CloudConfiguration
      , runnerHttpManager :: HTTP.Manager
      , runnerProblemDirectory :: FilePath
      , runnerBuildTests :: BuildTests
      , runnerGitConfiguration :: GitConfiguration
      , runnerFileLockSet :: LockSet FilePath
    }

data BuildTests = BuildTests {
    coreTests :: [(BuildTest, Aeson.Value)]
  , performanceTests :: [(BuildTest, Aeson.Value)]
  , optionalTests :: [(BuildTest, Aeson.Value)]
  }

data BuildTest = 
    BuildTestCore (Entity ContestCoreTest)
  | BuildTestPerformance (Entity ContestPerformanceTest)
  | BuildTestOptional (Entity ContestOptionalTest)

class ExtractContest a where
    extractContest :: a -> Entity Contest

extractContestId :: ExtractContest a => a -> ContestId
extractContestId = entityKey . extractContest

class ProblemRunnerClass runner where

    runOracleSubmission :: runner -> RunnerOptions -> Entity OracleSubmission -> DatabaseM (Maybe Bool) -- Return Nothing means timeout. True means success.

    runBuildSubmission :: runner -> RunnerOptions -> Entity BuildSubmission -> DatabaseM (Maybe (Bool, Bool)) -- Return Nothing means timeout. True means success, rescore.

    runBreakSubmission :: runner -> RunnerOptions -> Entity BreakSubmission -> DatabaseM (Maybe (Bool, Bool)) -- Return Nothing means timeout. True means success, rescore.
    
    runFixSubmission :: runner -> RunnerOptions -> Entity FixSubmission -> DatabaseM (Maybe (Bool, Bool)) -- Return Nothing means timeout. True means success, rescore.


