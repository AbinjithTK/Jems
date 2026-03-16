"""API Gateway + Lambda construct.

Chat/agent endpoints run on Google Cloud Run (not Lambda).
This construct only handles CRUD routes + scheduler Lambda.
"""

from constructs import Construct

import aws_cdk as cdk
import aws_cdk.aws_apigateway as apigw
import aws_cdk.aws_lambda as _lambda
import aws_cdk.aws_s3 as s3
import aws_cdk.aws_secretsmanager as sm

from .database import DatabaseConstruct


class ApiConstruct(Construct):
    """Creates API Gateway REST API + CRUD/Scheduler Lambdas.

    Agent/chat/WebSocket endpoints are served by Cloud Run (separate deploy).
    """

    def __init__(
        self,
        scope: Construct,
        id: str,
        db: DatabaseConstruct,
        secrets: sm.Secret,
        memory_bucket: s3.Bucket,
        stage: str,
    ) -> None:
        super().__init__(scope, id)

        # Shared environment variables for all Lambdas
        common_env = {
            "STAGE": stage,
            "USERS_TABLE": db.users_table.table_name,
            "MESSAGES_TABLE": db.messages_table.table_name,
            "GOALS_TABLE": db.goals_table.table_name,
            "TASKS_TABLE": db.tasks_table.table_name,
            "REMINDERS_TABLE": db.reminders_table.table_name,
            "SKILLS_TABLE": db.skills_table.table_name,
            "INSIGHTS_TABLE": db.insights_table.table_name,
            "ACCESS_CODES_TABLE": db.access_codes_table.table_name,
            "CONNECTIONS_TABLE": db.connections_table.table_name,
            "MCP_SERVERS_TABLE": db.mcp_servers_table.table_name,
            "JOURNAL_TABLE": db.journal_table.table_name,
            "AGENT_CONTEXT_TABLE": db.agent_context_table.table_name,
            "MEMORY_BUCKET": memory_bucket.bucket_name,
            "SECRETS_ARN": secrets.secret_arn,
            "COGNITO_USER_POOL_ID": "us-east-1_Bn4GrzTdg",
            "COGNITO_CLIENT_ID": "6v0sh32keeunk2e0j2sqlup6n",
        }

        # --- CRUD Lambda (512MB / 30s) ---
        # Handles all /api/* routes EXCEPT /api/chat and /api/ws/*
        self.crud_fn = _lambda.Function(
            self, "CrudFunction",
            function_name=f"jumns-crud-{stage}",
            runtime=_lambda.Runtime.PYTHON_3_12,
            handler="app.main.handler",
            code=_lambda.Code.from_asset(
                "../app",
                exclude=["agent/**", "memory/**", "__pycache__/**"],
            ),
            memory_size=512,
            timeout=cdk.Duration.seconds(30),
            environment=common_env,
        )

        # --- Scheduler Lambda (1024MB / 120s) ---
        self.scheduler_fn = _lambda.Function(
            self, "SchedulerFunction",
            function_name=f"jumns-scheduler-{stage}",
            runtime=_lambda.Runtime.PYTHON_3_12,
            handler="app.scheduler.handler.morning_briefing_handler",
            code=_lambda.Code.from_asset("../app"),
            memory_size=1024,
            timeout=cdk.Duration.seconds(120),
            environment=common_env,
        )

        # Grant DynamoDB access
        for table in db.all_tables:
            table.grant_read_write_data(self.crud_fn)
            table.grant_read_write_data(self.scheduler_fn)

        # Grant S3 memory bucket access
        memory_bucket.grant_read_write(self.crud_fn)
        memory_bucket.grant_read_write(self.scheduler_fn)

        # Grant Secrets Manager read access
        secrets.grant_read(self.crud_fn)
        secrets.grant_read(self.scheduler_fn)

        # --- API Gateway ---
        self.api = apigw.RestApi(
            self, "JumnsApi",
            rest_api_name=f"jumns-api-{stage}",
            deploy_options=apigw.StageOptions(stage_name="prod"),
            default_cors_preflight_options=apigw.CorsOptions(
                allow_origins=apigw.Cors.ALL_ORIGINS,
                allow_methods=apigw.Cors.ALL_METHODS,
            ),
        )

        # /api/{proxy+} → CRUD Lambda (catch-all for data routes)
        api_resource = self.api.root.add_resource("api")
        api_resource.add_proxy(
            default_integration=apigw.LambdaIntegration(self.crud_fn),
            any_method=True,
        )

        # /health → CRUD Lambda (unauthenticated)
        health_resource = self.api.root.add_resource("health")
        health_resource.add_method(
            "GET", apigw.LambdaIntegration(self.crud_fn)
        )

        # Output the API URL
        cdk.CfnOutput(
            self, "ApiUrl",
            value=self.api.url,
            description="Jumns API Gateway endpoint URL (CRUD only)",
        )
