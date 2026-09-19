# Making model quality gates control the serving path

A model report and a prediction endpoint can both work while evaluating and
serving different models. In the rental-price project, packaging produced an
artifact, but the API fitted another estimator at startup. A registry version or
Kubernetes label could therefore change without changing the prediction function.

The repair connects three contracts: validate the measurement, approve the
artifact, and load that artifact in the serving process.

## A gate must reject invalid measurements

Comparisons with NaN are false. A gate that only checks `rmse > limit` can therefore
accept an invalid metric. The evaluator now checks finiteness first, reports
non-finite metrics as invalid, and emits JSON-compatible nulls in failed reports.
Dataset validation and prediction inputs reject non-finite values too. Constant
targets use an explicit finite R2 convention: 1 for perfect predictions, 0 otherwise.

The test suite includes injected NaN metrics and constant-target cases. Those
tests exercise decisions, not merely the presence of a quality-report file.

## A rejected candidate must not replace a working artifact

Artifact creation evaluates the candidate before writing. A failed gate raises
an error and preserves any existing file. A successful write uses a temporary
file in the destination directory followed by an atomic replacement.

The bundle records feature order, training configuration, dataset digest, feature
ranges and quality evidence. These fields support reproducibility and monitoring.
They are not a signature or proof that an external artifact is trustworthy.

## Inference must use the selected artifact

`MODEL_ARTIFACT_PATH` selects the model actually loaded by the API. Artifact mode
does not retrain and does not need the original CSV. Startup rejects missing,
failed or incompatible bundles. `/health` returns the artifact digest so an
operator can verify what is serving. The documented sample-training mode remains
available for local exploration.

One integration test removes access to the CSV and makes the training function
raise if called, then exercises the HTTP prediction endpoint. Another packages
a different target scale and reversed feature order and checks the actual
prediction. This distinguishes working model selection from metadata-only changes.

HTTP boundary tests matter too: raw NaN in a request can be rejected by Pydantic
yet break the default error serializer if it echoes that value. Sanitized
validation errors return 422 without including the raw invalid input.

## Deployment configuration is part of the contract

The Docker build packages an approved sample artifact. The Helm deployment
explicitly starts the API and selects that artifact; it does not rely on the
image's pipeline-compilation default command. Container CI builds the image,
checks artifact-backed health and makes a real HTTP prediction.

Kubeflow also needs a real data handoff. A path on the submitter's laptop is not
inside the training container. The pipeline now accepts a storage URI and wires
a typed Dataset artifact from an importer to the training component. Compilation
is tested; a full cluster execution still needs configured storage and credentials.

## Limits and tradeoffs

- Pickle supports the small scikit-learn example but must only be loaded from a
  trusted build process. This repository does not sign or sandbox model files.
- The local registry is JSON metadata, not a complete model-promotion service.
- Process-local counters need per-replica scraping and aggregation.
- Offline tests and sample-data gates are engineering evidence, not a claim of
  rental accuracy on a representative real-market dataset.
- A successful local or container test does not establish cloud reliability,
  capacity or availability under production load.

## Reproduce and inspect

See [Rental Price MLOps Pipeline](https://github.com/mrsddq/rental-price-mlops-pipeline),
especially [`artifacts.py`](https://github.com/mrsddq/rental-price-mlops-pipeline/blob/main/rental_mlops/artifacts.py),
[`quality.py`](https://github.com/mrsddq/rental-price-mlops-pipeline/blob/main/rental_mlops/quality.py),
[`serving.py`](https://github.com/mrsddq/rental-price-mlops-pipeline/blob/main/rental_mlops/serving.py),
[`test_numeric_boundaries.py`](https://github.com/mrsddq/rental-price-mlops-pipeline/blob/main/tests/test_numeric_boundaries.py),
and [`test_serving_artifact.py`](https://github.com/mrsddq/rental-price-mlops-pipeline/blob/main/tests/test_serving_artifact.py).
Run the following commands from the root of that repository:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e '.[dev]'
python -m pytest -q
python main.py --no-compile --write-artifact --artifact-path outputs/model/rental-price-model.pkl
MODEL_ARTIFACT_PATH=outputs/model/rental-price-model.pkl uvicorn rental_mlops.serving:create_app --factory
```

The useful evidence is the connection between a failure case, a tested repair,
and the behavior of the delivered program.
