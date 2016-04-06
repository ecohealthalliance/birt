all: download restore

download:
	echo "This may take a while..."
	wget -c https://s3.amazonaws.com/birt-data/birt-db-dump.tar.gz
	tar xfz birt-db-dump.tar.gz

restore:
	echo "Upserting data dumps..."
	mongorestore -h localhost:3201 -d meteor -c birds dump/birt/birds.bson
	mongorestore -h localhost:3201 -d meteor -c migrations dump/birt/migrations.bson
	mongorestore -h localhost:3201 -d meteor -c halunka:i18n ./dump/birt/halunka:i18n.bson
