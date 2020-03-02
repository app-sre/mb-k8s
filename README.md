# mb k8s

This is a quick wrapper of [mb  load tester](https://github.com/jmencak/mb) on a kubernetes job that can run in parallel. The job spec includes an antiaffinity rule to force the pods to be scheduled in different nodes. Once the jobs are done, the results will be sent into a S3 bucket but mb can consume multiple result files to create a single report or a single plot. The [runner script](./attack.sh) is prepared to sent partial results if process is terminated via `SIGINT` or `SIGTERM` but kubernetes seems to delete jobs forcibly and reports won't be sent to S3 in that case. At least, we have a kill switch for the tests.

In order to run the tests, a helm v3 [chart](./helm/mb-k8s) has been provided. In order to deploy it:
```
helm install <release name> helm/mb-k8s [options]
```
If you don't want to use helm, you can use `helm template` to render the templates and install it via standard `kubectl`.

## Helm chart configuration values

|Parameter|Description|
|---|---|
|**Attack options**|
|`app.s3BucketName`|S3 bucket name to copy mb result bin file|
|`app.awsAccessKeyId`|AWS Access Key Id|
|`app.awsSecretAccessKey`|AWS Secret Access KeyId|
|`app.awsDefaultRegion`|AWS Region|
|`app.awsSecretName`|Secret containing AWS credentials|
|`app.duration`|mb `--duration` argument|
|`app.rampUp`|mb `--ramp-up` argument|
|`app.storeOutput`|Send the result files to S3 bucket|
|`app.requestConfigMap`|Configmap containing mb json `--request-file`|
|`app.requestConfigMapSubPath`|Name of the key in the requests configmap|

AWS credentials can be provided directly in the values (not recommended) or creating a secret name (much better) and referencing it. Take a look into [`secret.yaml`](helm/mb-k8s/templates/secret.yaml) in order to see the names of the keys.

For a complete description of `mb` arguments, see https://github.com/jmencak/mb

In order to create the request configmaps you can use the [`build-request-json.sh`](utils/build-request-json.sh), e.g
```
./utils/build-request-json.sh -f targets.txt -k 1 -c 50 -d 0 -t > request-file-1ka-50c.json
oc create configmap --from-file=request-file-1ka-50c.json request-file-1ka-50c
```
See [values.yaml](helm/mb-k8s/values.yaml) of the helm chart in order to find a complete list of the options available

## Report

A `vegeta` style report can be found in [`mb-report.py`](utils/mb-report.py). It uses the xz compressed result files that are stored in the S3 bucket
