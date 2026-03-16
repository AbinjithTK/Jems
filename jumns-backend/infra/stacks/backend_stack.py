"""Single CDK stack composing all Jumns backend constructs."""

import aws_cdk as cdk
import aws_cdk.aws_secretsmanager as sm
from constructs import Construct

import sys
import os

# Add infra directory to path for local construct imports
_infra_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _infra_dir not in sys.path:
    sys.path.insert(0, _infra_dir)

from infra_constructs.database import DatabaseConstruct
from infra_constructs.vector_store import VectorStoreConstruct
from infra_constructs.api import ApiConstruct
from infra_constructs.scheduling import SchedulingConstruct


class JumnsBackendStack(cdk.Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        stage: str,
        **kwargs,
    ) -> None:
        super().__init__(scope, id, **kwargs)

        # 1. Database — 12 DynamoDB tables
        db = DatabaseConstruct(self, "Database", stage=stage)

        # 2. Memory Store — S3 bucket for vector memory JSON files
        memory = VectorStoreConstruct(self, "VectorStore", stage=stage)

        # 3. Secrets Manager — API keys
        secrets = sm.Secret(
            self, "ApiKeys",
            secret_name=f"jumns-api-keys-{stage}",
            description="Gemini and failover model API keys",
        )

        # 4. API Gateway + Lambda functions
        api = ApiConstruct(
            self, "Api",
            db=db,
            secrets=secrets,
            memory_bucket=memory.bucket,
            stage=stage,
        )

        # 5. EventBridge Scheduler
        SchedulingConstruct(
            self, "Scheduling",
            scheduler_fn=api.scheduler_fn,
            stage=stage,
        )

        # 6. Tags
        cdk.Tags.of(self).add("project", "jumns")
        cdk.Tags.of(self).add("environment", stage)
