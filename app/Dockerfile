# syntax=docker/dockerfile:1
ARG GO_VERSION=1.27.2

FROM golang:${GO_VERSION}-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
# The release identity is baked into the binary so that a "bad" release differs
# from a good one only by its image tag, never by Kubernetes config.
ARG VERSION=dev
ARG COLOR=grey
ARG FAULT_MODE=
RUN CGO_ENABLED=0 go build -trimpath \
      -ldflags "-s -w -X main.version=${VERSION} -X main.color=${COLOR} -X main.faultMode=${FAULT_MODE}" \
      -o /out/demo-app .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/demo-app /demo-app
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/demo-app"]
