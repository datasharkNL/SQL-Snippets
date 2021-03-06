USE [DB_SSIS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tbl_edwr_ReconciliationLog]') AND TYPE IN (N'U'))
BEGIN
CREATE TABLE [dbo].[tbl_edwr_ReconciliationLog](
	[edrl_ReconciliationID_nbr] [INT] IDENTITY(1,1) NOT NULL,
	[pexl_LogID_nbr] [INT] NOT NULL,
	[edrl_ReconciliationStatus_txt] [VARCHAR](255) NOT NULL,
	[edrl_SourceCount_nbr] [INT] NULL,
	[edrl_StageCount_nbr] [INT] NULL,
	[edrl_NewCount_nbr] [INT] NULL,
	[edrl_UpdateCount_nbr] [INT] NULL,
	[edrl_HistoryCount_nbr] [INT] NULL,
	[edrl_UnchangedCount_nbr] [INT] NULL,
	[edrl_DeleteCount_nbr] [INT] NULL,
	[edrl_ErrorCount_nbr] [INT] NULL,
	[edrl_ReconciliationEnd_ts] [DATETIME] NULL,
	[edrl_ReconciliationLastUpdate_ts] [DATETIME] NOT NULL,
 CONSTRAINT [idx_ReconciliationLog_p_cl_01] PRIMARY KEY CLUSTERED 
(
	[edrl_ReconciliationID_nbr] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
SET ANSI_PADDING OFF
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tbl_edwr_ReconciliationLog]') AND name = N'idx_edwr_ReconciliationLog_i_nc_02')
CREATE NONCLUSTERED INDEX [idx_edwr_ReconciliationLog_i_nc_02] ON [dbo].[tbl_edwr_ReconciliationLog] 
(
	[pexl_LogID_nbr] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[usp_edwr_OnReconciliationEnd]') AND TYPE IN (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'-- ==========================================================================================
-- Author:		Ravi Gudlavalleti
-- Create date: Oct 24, 2007

-- Description:	This procedure adds a log entry into the tbl_mrrl_ReconciliationLog table
-- with reconciliation counts captured in the package and a status message.
-- If Reconciliation flag is set to 1, the logic is computed in this SP.
-- If its set to 0, the logic has to be performed in the package and the values must be passed
-- to this procedure for logging only.
-- ==========================================================================================
-- Updates: 
-- Oct 31, 2007 - Ravi Gudlavalleti - Added reconciliation logic and flag
-- Nov 07, 2007	(Ravi Gudlavalleti) - Made table and column name changes to conform to new standards
-- Dec 05, 2007	(Ravi Gudlavalleti) - Reduced number of counts logged - for MRS Contests
-- Sept 11, 2008 (Ravi Gudlavalleti) - Made changes for EDW PMR project. 
--										Added new counts and created new reconciliation table
-- ==========================================================================================
/* ------------------Review History ---------------------
09/19/2008	new procedure-approved		CK Bhatia
---------------------------------------------------------
*/
CREATE PROCEDURE [dbo].[usp_edwr_OnReconciliationEnd]

		@LogID					INT,
		@ReconciliationFlag		INT,
		@ReconciliationStatus	VARCHAR(255),	
		@SourceCount			INT,
		@StageCount				INT,
		@NewCount				INT,
		@UpdateCount			INT,
		@HistoryCount			INT,
		@UnchangedCount			INT,
		@DeleteCount			INT,
		@ErrorCount				INT

WITH EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errorFlag			INT

-- Compute reconciliation logic in the stored procedure, raise errors if necessary, if flag is set to 1

-- ==================================================================================
-- NOTE: Complete logic needs to be implemented. Coming Soon.
-- ==================================================================================

IF @ReconciliationFlag = 1
BEGIN
	-- Source to Stage count
	IF @SourceCount <> @StageCount
		BEGIN
			SET @ReconciliationStatus = ''ERROR - Source COUNT IS NOT equal TO Stage COUNT''
			SET @errorFlag = 1
		END
	-- Stage to Type 1 & Type 2 counts
	IF @StageCount <> (@NewCount + @UpdateCount + @HistoryCount + @UnchangedCount)
		BEGIN
			SET @ReconciliationStatus = ''ERROR - Stage COUNT IS NOT equal TO SUM OF NEW, UPDATE, History & Unchanged counts''
			SET @errorFlag = 1
		END
	-- Set flag and status to success if all the counts add up
	ELSE
		BEGIN
			SET @ReconciliationStatus = ''Reconciliation Successful. ALL counts MATCH''
			SET @errorFlag = 0
		END
END -- IF @ReconciliationFlag = 1

-- Log reconciliation counts to the reconciliation log table, regardless of success or failure
INSERT INTO [dbo].[tbl_edwr_ReconciliationLog]
(
	[pexl_LogID_nbr], [edrl_ReconciliationStatus_txt], [edrl_SourceCount_nbr]
	,[edrl_StageCount_nbr], [edrl_NewCount_nbr], [edrl_UpdateCount_nbr]
	,[edrl_HistoryCount_nbr], [edrl_UnchangedCount_nbr], [edrl_DeleteCount_nbr]
	,[edrl_ErrorCount_nbr], [edrl_ReconciliationEnd_ts], [edrl_ReconciliationLastUpdate_ts]
)
VALUES
(
	@LogID, ISNULL(@ReconciliationStatus, ''''),
	ISNULL(@SourceCount, 0),ISNULL(@StageCount, 0), ISNULL(@NewCount, 0),
	ISNULL(@UpdateCount, 0), ISNULL(@HistoryCount, 0), ISNULL(@UnchangedCount, 0),
	ISNULL(@DeleteCount, 0), ISNULL(@ErrorCount, 0),
	GETDATE(),GETDATE()
)

-- Raise error with high severity and stop package, if error flag is set to 1
IF @errorFlag = 1 
	RAISERROR(@ReconciliationStatus, 18, 1) -- Error message, Severity, State

	SET NOCOUNT OFF
END
' 
END