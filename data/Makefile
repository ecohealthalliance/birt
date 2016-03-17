all: download restore

download:
	echo "This may take a while..."
	aws s3 cp s3://birt-data/birt-data.tar.gz .
	tar xfz birt-data.tar.gz

restore:
	echo "Upserting data dumps..."
	mongorestore -h localhost:3201 -d meteor -c birds birt/birds.bson
	mongorestore -h localhost:3201 -d meteor -c migrations birt/migrations.bson
