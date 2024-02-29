#FROM python:3.10-slim
#
#RUN apt-get update && apt-get install gcc g++ git make -y && apt-get clean \
#	&& rm -rf /var/lib/apt/lists/*
#RUN useradd -m -u 1000 user
#USER user
#ENV HOME=/home/user \
#	PATH=/home/user/.local/bin:$PATH
#
#WORKDIR $HOME/app
#
#COPY --chown=user . $HOME/app
#
#RUN pip install langflow>==0.5.0 -U --user
#CMD ["python", "-m", "langflow", "run", "--host", "0.0.0.0", "--port", "7860"]
FROM python:3.10-slim

WORKDIR /app

# Install Poetry
RUN apt-get update && apt-get install gcc g++ curl build-essential postgresql-server-dev-all -y
RUN curl -sSL https://install.python-poetry.org | python3 -
# # Add Poetry to PATH
ENV PATH="${PATH}:/root/.local/bin"
# # Copy the pyproject.toml and poetry.lock files
COPY poetry.lock pyproject.toml ./
# Copy the rest of the application codes
COPY ./ ./

# Install dependencies
RUN poetry config virtualenvs.create false && poetry install --no-interaction --no-ansi

CMD ["uvicorn", "--factory", "src.backend.langflow.main:create_app", "--host", "0.0.0.0", "--port", "7860", "--reload", "--log-level", "debug"]

FROM --platform=linux/amd64 node:19-bullseye-slim AS base
RUN mkdir -p /home/node/app
RUN chown -R node:node /home/node && chmod -R 770 /home/node
RUN apt-get update && apt-get install -y jq curl
WORKDIR /home/node/app

# client build
FROM base AS builder-client
ARG BACKEND_URL
ENV BACKEND_URL $BACKEND_URL
RUN echo "BACKEND_URL: $BACKEND_URL"

WORKDIR /home/node/app
COPY --chown=node:node . ./

COPY ./src/frontend/set_proxy.sh .
RUN chmod +x set_proxy.sh && \
    cat set_proxy.sh | tr -d '\r' > set_proxy_unix.sh && \
    chmod +x set_proxy_unix.sh && \
    ./set_proxy_unix.sh

USER node

RUN npm install --loglevel warn
CMD ["npm", "run", "vite --host 0.0.0.0"]