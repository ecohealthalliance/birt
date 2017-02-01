import { MongoClient } from 'mongodb'
import argv from 'yargs'

const args = argv
  .help('h')
  .alias('h', 'help')
  .option('u', {
    alias: 'url',
    describe: 'The mongodb url',
    default: 'mongodb://localhost:27017/birt'
  })
  .option('d', {
    alias: 'debug',
    describe: 'Enable debugging messages',
    default: false
  })
  .option('l', {
    alias: 'limit',
    describe: 'Specifiy the database record limit per year',
    default: 100000
  })
  .option('m', {
    alias: 'min_insertion',
    describe: 'Specify the minimum insertion threshold (number of sightings required to be included)',
    default: 100
  })
  .usage('Usage: $0 -u [mongodb://localhost:27017/birt] -d [boolean]')
  .argv;

const LIMIT = args.l;
const DEBUG = args.d;
const URL = args.u;
const MIN_INSERTION_COUNT = args.m;
const FIRST_YEAR = 1887;
const LAST_YEAR = 2012;
let START_TIME = 0;

/*
 * builds an array of years based on FIRST_YEAR and LAST_YEAR
 *
 * @return {array} years
 */
function getYearlyRange() {
  const years = [];
  let low = FIRST_YEAR;
  const high = LAST_YEAR;
  while (low <= high) {
    years.push(low++);
  }
  return years;
}

/*
 * determines the annual sightings for each bird
 *
 * @param {object} collections, the mongodb collections
 * @param {function} done, the callback to execute when done
 */
function getAnnualCounts(collections, done) {
  let processed = 0;
  const annual = {};
  const years = getYearlyRange();
  years.forEach((year) => {
    const startDate = new Date(Date.UTC(year, 1, 1));
    const endDate = new Date(Date.UTC(year, 12, 31));
    const query = {
      date: {
        $gte: startDate,
        $lt: endDate
      }
    };
    const opts = {
      sightings: 1,
    }

    if (DEBUG) console.log('query: ', query);
    const cursor = collections.migrations.find(query, opts).limit(LIMIT);
    const counts = {};
    function processMigration(err, migration) {
      if (err || migration == null) {
        if (err) console.warn('err: ', err);
        processed++;
        if (DEBUG) console.log('processed: ', processed, ' of ', years.length);
        if (years.length == processed) {
          done(null, annual);
        }
        return;
      }
      if (DEBUG) console.log('migration.sightings.length: ', migration.sightings.length);
      let numSightings = 0;
      migration.sightings.forEach((sighting) => {
        const bird_id = `${sighting.bird_id}`;
        let count = counts[bird_id];
        if (typeof count == 'undefined') {
          count = sighting.count;
        } else {
          count += sighting.count;
        }
        counts[bird_id] = count;
        let annualCounts = annual[year];
        if (typeof annualCounts == 'undefined') {
          annualCounts = {};
        }
        let annualCount = annualCounts[bird_id];
        if (typeof annualCount == 'undefined') {
          annualCount = count;
        } else {
          annualCount += count;
        }
        annualCounts[bird_id] = annualCount;
        annual[year] = annualCounts;
        if (DEBUG) console.log('sightings processed: ', ++numSightings, ' of ', migration.sightings.length);
      });
      cursor.nextObject(processMigration);
    }
    cursor.nextObject(processMigration);
  });
}

/*
 * determines the year with the maximum count for each species
 *
 * @param {object} annual, hash map of years species counts
 */
function selectMax(annual) {
  const max = {};
  Object.keys(annual).forEach((year) => {
    Object.keys(annual[year]).forEach((species) => {
      const count = annual[year][species];
      let maxCount = max[species];
      if (typeof maxCount == 'undefined') {
        maxCount = {count: count, year: year};
      } else {
        if (maxCount.count < count) {
          maxCount.count = count;
          maxCount.year = year;
        }
      }
      if (DEBUG) console.log(`annual[${year}][${species}] count:${count} maxCount: ${maxCount.count}`)
      max[species] = maxCount
    });
  });
  return max;
}

/*
 * return the recommended dates for a species
 *
 * @param {number} year, the year to recommend
 */
function getRecommendedDates(year) {
  const recommendedDates = {};
  recommendedDates.startDate = `${year}-01-01`;
  recommendedDates.endDate = `${year}-12-31`;
  return recommendedDates;
}

/* sets the recommended_dates within the database on the bird collection
 *
 * @param {object} collections, the mongodb collections
 * @param {object} max, hash map of species max year
 * @done {function} done, method to execute when done
 */
function setRecommendedDates(collections, max) {
  Object.keys(max).forEach((species) => {
    const bird = collections.birds.findOne({_id: species});
    const count = max[species].count;
    const year = max[species].year;
    if (typeof bird != 'undefined' && count > MIN_INSERTION_COUNT) {
      const recommended_dates = getRecommendedDates(year);
      collections.birds.update({_id:bird._id}, {$set: {recommended_dates: recommended_dates}});
    } else {
      collections.invalidBirds.update({_id:species}, {updated: new Date()}, {upsert: true});
    }
  });
}

// connect to mongodb and getAnnualCounts
MongoClient.connect(URL, (err, db) => {
  const collections = {
    migrations: db.collection('migrations'),
    birds: db.collection('birds'),
    invalidBirds: db.collection('invalid_birds')
  };
  if (DEBUG) {
    START_TIME = new Date().getTime();
    console.log('Started setting recommended dates for species');
  }
  getAnnualCounts(collections, (err, annual) => {
    if (err) {
      return console.error(err);
    }
    setRecommendedDates(collections, selectMax(annual));
    if (DEBUG) console.log(`Finished setting recommended dates for species: ${new Date().getTime() - START_TIME} (ms)`);
    db.close()
    process.exit(0)
  });
});
