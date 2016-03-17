# BIRT data
The most crucial part of the app: bird migration data.

### Requirements
 - `awscli`

### Instructions
Simply type and run `make download` to pull the migration data from EHA's AWS S3 bucket.

After the data has been downloaded, while running the meteor application on port
3200 (`cd app/ && make run`), run `make restore` to import the downloaded BSON file
into the database instance accessible on port 3201.

The final step is to restart your application via `make run`.
