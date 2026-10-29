from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, SessionDep
from app.api.routes.workflows import create_workflow
from app.schemas.workflow import NodeTypeRead, TemplateRead, TemplateUse, WorkflowCreate, WorkflowRead
from app.services.templates import TEMPLATES, TEMPLATES_BY_SLUG
from app.services.workflow_definition import node_catalog

router = APIRouter(tags=["Catalog"])


def _template(t) -> TemplateRead:
    return TemplateRead(slug=t.slug, name=t.name, description=t.description, category=t.category,
                        requires=list(t.requires), definition=t.definition)


@router.get("/node-types", response_model=list[NodeTypeRead])
def node_types():
    return node_catalog()


@router.get("/templates", response_model=list[TemplateRead])
def list_templates():
    return [_template(t) for t in TEMPLATES]


@router.get("/templates/{slug}", response_model=TemplateRead)
def get_template(slug: str):
    template = TEMPLATES_BY_SLUG.get(slug)
    if template is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Template not found.")
    return _template(template)


@router.post("/templates/{slug}/use", response_model=WorkflowRead, status_code=status.HTTP_201_CREATED)
def use_template(slug: str, payload: TemplateUse, user: CurrentUser, db: SessionDep):
    template = TEMPLATES_BY_SLUG.get(slug)
    if template is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Template not found.")
    return create_workflow(
        WorkflowCreate(name=payload.name or template.name, description=template.description,
                       definition=template.definition),
        user,
        db,
    )
