#!/bin/bash

helm dependency build charts/media-stack && \
helm package charts/*
