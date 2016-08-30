module Handler.Participation.BreakSubmissions where

import qualified Database.Esqueleto as E
import Data.Time.Clock (getCurrentTime)
import Score

import qualified BreakSubmissions
import Import
import qualified Participation
import PostDependencyType

getParticipationBreakSubmissionsR :: TeamContestId -> Handler Html
getParticipationBreakSubmissionsR tcId = runLHandler $ 
    Participation.layout Participation.BreakSubmissions tcId $ \_ _ _ _ -> do
        -- submissions <- handlerToWidget $ runDB $ selectList [BreakSubmissionTeam ==. tcId] [Desc BreakSubmissionTimestamp]
        submissions <- handlerToWidget $ runDB $ [lsql| select BreakSubmission.*, Team.name from BreakSubmission inner join TeamContest on BreakSubmission.targetTeam == TeamContest.id inner join Team on TeamContest.team == Team.id where BreakSubmission.team == #{tcId} order by BreakSubmission.id desc |]
        -- E.select $ E.from $ \( s `E.InnerJoin` tc `E.InnerJoin` tt) -> do
        --     E.on ( tc E.^. TeamContestTeam E.==. tt E.^. TeamId)
        --     E.on ( s E.^. BreakSubmissionTargetTeam E.==. tc E.^. TeamContestId)
        --     E.where_ ( s E.^. BreakSubmissionTeam E.==. E.val tcId)
        --     E.orderBy [E.desc (s E.^. BreakSubmissionTimestamp)]
        --     return (s, tt E.^. TeamName)
        case submissions of
            [] ->
                [whamlet|
                    <p>
                        No submissions were found. If you have made submissions, please ensure your git url is correct on the information page.
                |]
            _ ->
                let row (Entity sId s, target) = do
                    let status = prettyBreakStatus $ breakSubmissionStatus s
                    let result = prettyBreakResult $ breakSubmissionResult s
                    time <- lLift $ lift $ displayTime $ breakSubmissionTimestamp s
                    return [whamlet'|
                        <tr .clickable href="@{ParticipationBreakSubmissionR tcId sId}">
                            <td>
                                #{breakSubmissionName s}
                            <td>
                                #{time}
                            <td>
                                #{target}
                            <td>
                                #{status}
                            <td>
                                #{result}
                    |]
                in
                do
                rows <- mapM row submissions
                [whamlet|
                    <table class="table table-hover">
                        <thead>
                            <tr>
                                <th>
                                    Test name
                                <th>
                                    Timestamp
                                <th>
                                    Target Team
                                <th>
                                    Status
                                <th>
                                    Result
                        <tbody>
                            ^{mconcat rows}
                |]
        againstW <- handlerToWidget $ do
            ss <- runDB $ [lsql| select BreakSubmission.*, Team.name from BreakSubmission inner join TeamContest on BreakSubmission.team == TeamContest.id inner join Team on Team.id == TeamContest.team where BreakSubmission.targetTeam == #{tcId} order by BreakSubmission.id desc |]
            -- E.select $ E.from $ \( s `E.InnerJoin` tc `E.InnerJoin` tt) -> do
            --     E.on ( tc E.^. TeamContestTeam E.==. tt E.^. TeamId)
            --     E.on ( s E.^. BreakSubmissionTeam E.==. tc E.^. TeamContestId)
            --     E.where_ ( s E.^. BreakSubmissionTargetTeam E.==. E.val tcId)
            --     E.orderBy [E.desc (s E.^. BreakSubmissionTimestamp)]
            --     return (s, tt E.^. TeamName)
            case ss of 
                [] ->
                    return $ [whamlet'|
                        <p>
                            No submissions have targeted against your team.
                    |]
                _ ->
                    let row (Entity sId s, attacker) = 
                          let status = prettyBreakStatusVictim $ breakSubmissionStatus s in
                          let result = prettyBreakResultVictim $ breakSubmissionResult s in
                          let bType = maybe dash prettyBreakType $ breakSubmissionType s in
                          do
                          fixStatus <- prettyFixStatus sId
                          time <- lLift $ lift $ displayTime $ breakSubmissionTimestamp s
                          return [whamlet'|
                            <tr .clickable href="@{ParticipationBreakSubmissionR tcId sId}">
                                <td>
                                    #{breakSubmissionName s} (#{keyToInt sId})
                                <td>
                                    #{time}
                                <td>
                                    #{attacker} (#{keyToInt $ breakSubmissionTeam s})
                                <td>
                                    #{status}
                                <td>
                                    #{result}
                                <td>
                                    #{bType}
                                <td>
                                    #{fixStatus}
                          |]
                    in
                    do
                    rows <- mapM row ss
                    return [whamlet'|
                        <table class="table table-hover">
                            <thead>
                                <tr>
                                    <th>
                                        Test name
                                    <th>
                                        Timestamp
                                    <th>
                                        Attacking Team
                                    <th>
                                        Status
                                    <th>
                                        Result
                                    <th>
                                        Type
                                    <th>
                                        Fix Status
                            <tbody>
                                ^{mconcat rows}
                    |]
        [whamlet|
            <h3>
                Against your team
            ^{againstW}
        |]
        clickableDiv

    where
        prettyFixStatus bsId = do
            disputeM <- runDB $ getBy $ UniqueBreakDispute bsId
            case disputeM of
                Just _ ->
                    return [shamlet|
                        <span>
                            Disputed
                    |]
                Nothing -> do
                    -- Check if a non pending/rejected fix exists.
                    fixs <- runDB $ E.select $ E.from $ \(E.InnerJoin f fb) -> do
                        E.on (f E.^. FixSubmissionId E.==. fb E.^. FixSubmissionBugsFix)
                        E.where_ (fb E.^. FixSubmissionBugsBugId E.==. E.val bsId E.&&.
                            (f E.^. FixSubmissionStatus E.==. E.val FixBuilt E.||. f E.^. FixSubmissionStatus E.==. E.val FixJudging E.||. f E.^. FixSubmissionStatus E.==. E.val FixJudged))
                        return fb
                    case fixs of
                        [_a] ->
                            return [shamlet|
                                <span>
                                    Submitted
                            |]
                        _ ->
                            return dash



getParticipationBreakSubmissionR :: TeamContestId -> BreakSubmissionId -> Handler Html
getParticipationBreakSubmissionR tcId bsId = runLHandler $ do
    res <- runDB $ get bsId
    case res of
        Nothing ->
            notFound
        Just bs ->
            if ( breakSubmissionTeam bs) /= tcId && ( breakSubmissionTargetTeam bs) /= tcId then
                notFound
            else
                let victim = (breakSubmissionTargetTeam bs) == tcId in
                Participation.layout Participation.BreakSubmissions tcId $ \userId teamcontest contest team -> do
                    let status = (if victim then
                            prettyBreakStatusVictim
                          else
                            prettyBreakStatus
                          ) $ breakSubmissionStatus bs
                    let result = (if victim then
                            prettyBreakResultVictim
                          else
                            prettyBreakResult 
                          ) $ breakSubmissionResult bs
                    let message = case breakSubmissionMessage bs of
                          Nothing -> dash
                          Just msg -> [shamlet|
                            <span>
                                #{msg}
                            |]
                    let testType = case breakSubmissionType bs of
                          Nothing -> dash
                          Just typ -> prettyBreakType typ 
                    time <- lLift $ lift $ displayTime $ breakSubmissionTimestamp bs
                    (attackTeamName,targetTeam) <- do
                        res <- handlerToWidget $ runDB $ BreakSubmissions.getBothTeams bsId $ \(Entity _ t) _tc _bs _tct (Entity _ tt) ->
                            ( teamName t, tt)
                        case res of
                            Just names ->
                                return names
                            _ ->
                                notFound

                    let targetTeamName = teamName targetTeam

                    -- Judgement widget.
                    judgementW <- do
                        judgementM <- handlerToWidget $ runDB $ getBy $ UniqueBreakJudgement bsId
                        return $ case judgementM of
                            Nothing ->
                                mempty
                            Just (Entity jId j) ->
                                let ruling = case breakJudgementRuling j of
                                      Nothing ->
                                        [shamlet|
                                            <span>
                                                Pending
                                        |]
                                      Just True ->
                                        [shamlet|
                                            <span class="text-success">
                                                Passed
                                        |]
                                      Just False ->
                                        [shamlet|
                                            <span class="text-danger">
                                                Failed
                                        |]
                                in
                                let comments = case breakJudgementComments j of
                                      Nothing ->
                                        dash
                                      Just c ->
                                        toHtml c
                                in
                                [whamlet'|
                                    <div class="form-group">
                                        <label class="col-xs-3 control-label">
                                            Judgment
                                        <div class="col-xs-9">
                                            <p class="form-control-static">
                                                #{ruling}
                                    <div class="form-group">
                                        <label class="col-xs-3 control-label">
                                            Judge comments
                                        <div class="col-xs-9">
                                            <p class="form-control-static">
                                                #{comments}
                                |]

                    now <- lLift $ liftIO getCurrentTime

                    disputeW <- do
                        -- TODO: Check if a dispute exists. 
                        disputeM <- handlerToWidget $ runDB $ getBy $ UniqueBreakDispute bsId
                        case disputeM of
                            Just (Entity _ (BreakDispute _ justification)) ->
                                return [whamlet'|
                                    <h3>
                                        Dispute
                                    <form class="form-horizontal">
                                        <div class="form-group">
                                            <label class="col-xs-3 control-label">
                                                Justification
                                            <div class="col-xs-9">
                                                <p class="form-control-static">
                                                    #{justification}
                                |]
                            Nothing -> 
                                if not development && (not victim || now < contestFixStart contest || now > contestFixEnd contest) then
                                  return mempty
                                else
                                  -- Check if team leader.
                                  if userId /= teamLeader targetTeam then
                                      return [whamlet'|
                                          <h3>
                                              Dispute
                                          <p>
                                              Only the team leader may dispute a break submission. 
                                      |]
                                  else
                                      -- Check that the break result is accepted.
                                      let res = breakSubmissionResult bs in
                                      if res /= Just BreakCorrect && res /= Just BreakExploit then
                                          return [whamlet'|
                                              <h3>
                                                  Dispute
                                              <p>
                                                  You may only dispute accepted breaks.
                                          |]
                                      else do
                                          --TODO: Check if already disputed
                                          (disputeW, disputeE) <- handlerToWidget $ generateFormPost disputeBreakSubmissionForm
                                          return [whamlet'|
                                              <h3>
                                                  Dispute
                                              <p>
                                                  If you believe this break is incorrect, write a justification for why you think it is invalid. The justification (no more than 100 words) should indicate why your system's behavior is acceptable according to the spec, even if the oracle behaves differently. 
                                                  We will review the dispute during the judging phase. 
                                              <form role=form method=post action="@{ParticipationBreakSubmissionDisputeR tcId bsId}" enctype=#{disputeE}>
                                                  ^{disputeW}
                                          |]
                                    

                    -- Build output widget.
                    let buildOutputW = case (victim, breakSubmissionStatus bs, breakSubmissionStdout bs, breakSubmissionStderr bs) of
                          (False, BreakRejected, Just stdout, Just stderr) ->
                            [whamlet'|
                                <h4>
                                    Standard Output from Make
                                <samp>
                                    #{stdout}
                                <h4>
                                    Standard Error from Make
                                <samp>
                                    #{stderr}
                            |]
                          _ ->
                            mempty

                    -- Delete widget.
                    deleteW <- do
                        -- Check that not on victim team, and it's during the break it round.
                        if not development && (victim || now < contestBreakStart contest || now > contestBreakEnd contest) then
                            return mempty
                          else 
                            -- Check if team leader.
                            if userId == teamLeader team then
                                -- Check that the break is finished testing. 
                                let st = breakSubmissionStatus bs in
                                if st == BreakPending || st == BreakTesting then
                                    return [whamlet'|
                                        <h3>
                                            Delete
                                        <p>
                                            You cannot delete a break submission until it is finished being tested.
                                    |]
                                else do
                                    (deleteW, deleteE) <- handlerToWidget $ generateFormPost deleteBreakSubmissionForm
                                    return [whamlet'|
                                        <h3>
                                            Delete
                                        <p>
                                            Delete this break submission. 
                                        <p .text-danger>
                                            Warning: This cannot be undone!
                                        <form .form-inline role=form method=post action="@{ParticipationBreakSubmissionDeleteR tcId bsId}" enctype=#{deleteE}>
                                            ^{deleteW}
                                    |]
                            else
                                return [whamlet'|
                                    <h3>
                                        Delete
                                    <p>
                                        Only the team leader may delete a break submission. 
                                |]
                                
                    [whamlet|
                        <a href="@{ParticipationBreakSubmissionsR tcId}" type="button" class="btn btn-primary">
                            Back
                        <h2>
                            Break Submission
                        <form class="form-horizontal">
                            <div class="form-group">
                                <label class="col-xs-3 control-label">
                                    Submission ID
                                <div class="col-xs-9">
                                    <p class="form-control-static">
                                        #{keyToInt bsId}
                            <div class="form-group">
                                <label class="col-xs-3 control-label">
                                    Test name
                                <div class="col-xs-9">
                                    <p class="form-control-static">
                                        #{breakSubmissionName bs}
                            <div class="form-group">
                                <label class="col-xs-3 control-label">
                                    Test type
                                <div class="col-xs-9">
                                    <p class="form-control-static">
                                        #{testType}
                            <div class="form-group">
                                <label class="col-xs-3 control-label">
                                    Attacking Team
                                <div class="col-xs-9">
                                    <p class="form-control-static">
                                        #{attackTeamName} (#{keyToInt (breakSubmissionTeam bs)})
                            <div class="form-group">
                                <label class="col-xs-3 control-label">
                                    Target Team
                                <div class="col-xs-9">
                                    <p class="form-control-static">
                                        #{targetTeamName} (#{keyToInt (breakSubmissionTargetTeam bs)})
                            <div class="form-group">
                                <label class="col-xs-3 control-label">
                                    Submission hash
                                <div class="col-xs-9">
                                    <p class="form-control-static">
                                        #{breakSubmissionCommitHash bs}
                            <div class="form-group">
                                <label class="col-xs-3 control-label">
                                    Timestamp
                                <div class="col-xs-9">
                                    <p class="form-control-static">
                                        #{time}
                            <div class="form-group">
                                <label class="col-xs-3 control-label">
                                    Status
                                <div class="col-xs-9">
                                    <p class="form-control-static">
                                        #{status}
                            <div class="form-group">
                                <label class="col-xs-3 control-label">
                                    Result
                                <div class="col-xs-9">
                                    <p class="form-control-static">
                                        #{result}
                            <div class="form-group">
                                <label class="col-xs-3 control-label">
                                    Message
                                <div class="col-xs-9">
                                    <p class="form-control-static">
                                        #{message}
                            ^{judgementW}
                        ^{buildOutputW}
                        ^{disputeW}
                        ^{deleteW}
                    |]

data DisputeBreakForm = DisputeBreakForm Textarea

disputeBreakSubmissionForm :: Form DisputeBreakForm
disputeBreakSubmissionForm = renderBootstrap3 disp $ DisputeBreakForm <$>
       areq textareaField (withPlaceholder "Justification" $ bfs ("Justification" :: Text)) Nothing
    <* bootstrapSubmit (BootstrapSubmit ("Dispute"::Text) "btn btn-primary" [])

    where
        disp = BootstrapInlineForm
        -- disp = BootstrapHorizontalForm (ColMd 0) (ColMd 6) (ColMd 0) (ColMd 4)

postParticipationBreakSubmissionDisputeR :: TeamContestId -> BreakSubmissionId -> Handler ()
postParticipationBreakSubmissionDisputeR tcId bsId = runLHandler $ do
    userId <- requireAuthId
    ((res, widget), enctype) <- runFormPost disputeBreakSubmissionForm
    case res of 
        FormFailure _msg ->
            failureHandler
        FormMissing ->
            failureHandler
        FormSuccess (DisputeBreakForm justificationA) -> do
            -- Get break submission.
            bsM <- runDB $ get bsId
            case bsM of
                Nothing ->
                    notFound
                Just bs ->
                    -- Check that team is target.
                    if ( breakSubmissionTargetTeam bs) /= tcId then
                        failureHandler
                    else do
                        -- Check that user is team leader.
                        teamLeaderM <- runDB $ E.select $ E.from $ \(E.InnerJoin (E.InnerJoin tc c) t) -> do
                            E.on (tc E.^. TeamContestTeam E.==. t E.^. TeamId)
                            E.on (tc E.^. TeamContestContest E.==. c E.^. ContestId)
                            E.where_ (tc E.^. TeamContestId E.==. E.val tcId)
                            E.limit 1
                            return (t E.^. TeamLeader, c)
                        case teamLeaderM of
                            [(E.Value leader, (Entity _ contest))] | leader == userId -> do
                                -- Check that it's fix round.
                                now <- lLift $ liftIO getCurrentTime
                                if not development && ( now < contestFixStart contest || now > contestFixEnd contest) then
                                    failureHandler
                                else
                                    -- Check the break is accepted.
                                    let res = breakSubmissionResult bs in
                                    if res /= Just BreakCorrect && res /= Just BreakExploit then
                                        failureHandler
                                    else do
                                        runDB $ insert $ BreakDispute bsId $ unTextarea justificationA
                                        setMessage [shamlet|
                                            <div class="container">
                                                <div class="alert alert-success">
                                                    Successfully disputed break submission.
                                        |]
                                        redirect $ ParticipationBreakSubmissionR tcId bsId
                                        
                            _ ->
                                failureHandler
                        
            

    where
        failureHandler = do
            setMessage [shamlet|
                <div class="container">
                    <div class="alert alert-danger">
                        Could not dispute break submission.
            |]
            redirect $ ParticipationBreakSubmissionR tcId bsId


data DeleteForm = DeleteForm ()

deleteBreakSubmissionForm :: Form DeleteForm
deleteBreakSubmissionForm = renderBootstrap3 BootstrapInlineForm $ DeleteForm
    <$> pure ()
    <*  bootstrapSubmit (BootstrapSubmit ("Delete"::Text) "btn btn-danger" [])

postParticipationBreakSubmissionDeleteR :: TeamContestId -> BreakSubmissionId -> Handler ()
postParticipationBreakSubmissionDeleteR tcId bsId = runLHandler $ do
    raiseUserLabel
    ((res, widget), enctype) <- runFormPost deleteBreakSubmissionForm
    case res of
        FormFailure _msg ->
            failureHandler
        FormMissing ->
            failureHandler
        FormSuccess (DeleteForm ()) -> do
            bsM <- runDB $ E.select $ E.from $ \(E.InnerJoin (E.InnerJoin bs tc) t) -> do
                E.on (tc E.^. TeamContestTeam E.==. t E.^. TeamId)
                E.on (tc E.^. TeamContestId E.==. bs E.^. BreakSubmissionTeam)
                E.where_ (bs E.^. BreakSubmissionId E.==. E.val bsId)
                return ( bs, tc E.^. TeamContestContest, t)
            case bsM of
                [((Entity _ bs), (E.Value contestId), (Entity _ team))] -> do
                    -- Get contest.
                    contestM <- runDB $ get contestId
                    case contestM of
                        Nothing ->
                            failureHandler
                        Just contest -> 
                            -- Check that team submitted break. 
                            if ( breakSubmissionTeam bs) /= tcId then
                                failureHandler
                            else do
                                -- Check that it's break round.
                                now <- lLift $ liftIO getCurrentTime
                                if not development && ( now < contestBreakStart contest || now > contestBreakEnd contest) then
                                    failureHandler
                                else do
                                    -- Check that user is team leader.
                                    userId <- requireAuthId
                                    if userId /= teamLeader team then
                                        failureHandler
                                    else
                                        -- Check that the break is finished testing.
                                        let st = breakSubmissionStatus bs in
                                        if st == BreakPending || st == BreakTesting then
                                            failureHandler
                                        else do
                                            runDB $ delete bsId
                                            rescoreBreakRound contestId
                                            setMessage [shamlet|
                                                <div class="container">
                                                    <div class="alert alert-success">
                                                        Successfully deleted break submission.
                                            |]
                                            redirect $ ParticipationBreakSubmissionsR tcId
                            
                _ ->
                    failureHandler

    where
        failureHandler = do
            setMessage [shamlet|
                <div class="container">
                    <div class="alert alert-danger">
                        Could not delete break submission.
            |]
            redirect $ ParticipationBreakSubmissionR tcId bsId
