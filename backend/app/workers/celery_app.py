from celery import Celery

from app.core.config import settings

celery_app = Celery(
    "ghostwork",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["app.workers.tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    result_expires=3600,
    timezone="UTC",
    enable_utc=True,
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    worker_prefetch_multiplier=1,
    task_soft_time_limit=settings.EXECUTION_SOFT_TIME_LIMIT_SECONDS,
    task_time_limit=settings.EXECUTION_SOFT_TIME_LIMIT_SECONDS + 30,
    task_always_eager=settings.CELERY_TASK_ALWAYS_EAGER,
    task_eager_propagates=True,
    broker_connection_retry_on_startup=True,
    broker_transport_options={"visibility_timeout": settings.EXECUTION_SOFT_TIME_LIMIT_SECONDS * 3},
    beat_schedule={
        "dispatch-due-schedules": {"task": "ghostwork.dispatch_due_schedules", "schedule": 30.0},
        "reap-stale-executions": {"task": "ghostwork.reap_stale_executions", "schedule": 120.0},
        "purge-old-executions": {"task": "ghostwork.purge_old_executions", "schedule": 6 * 3600.0},
    },
)
