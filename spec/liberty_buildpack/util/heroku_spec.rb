# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'spec_helper'
require 'liberty_buildpack/util/heroku'

module LibertyBuildpack::Util

  describe 'Detect' do

    after (:each) do
      ENV.delete('DYNO')
    end

    it 'Heroku environment' do
      ENV['DYNO'] = 'web.1'
      expect(Heroku.heroku?).to be_true
    end

    it 'Non Heroku environment' do
      ENV.delete('DYNO')
      expect(Heroku.heroku?).to be_false
    end

  end

  describe 'VCAP_SERVICES' do

    def check_database_url(vcap_services)
      services = vcap_services['DATABASE_URL']
      expect(services).to have(1).items
      expect(services[0]['name']).to match('database')
      credentials = services[0]['credentials']
      expect(credentials).to have(9).items
      expect(credentials['host']).to match('foo')
      expect(credentials['hostname']).to match('foo')
      expect(credentials['port']).to eq(500)
      expect(credentials['user']).to match('u')
      expect(credentials['username']).to match('u')
      expect(credentials['password']).to match('p')
      expect(credentials['name']).to match('bar')
      expect(credentials['uri']).to match('http://u:p@foo:500/bar')
      expect(credentials['url']).to match('http://u:p@foo:500/bar')
      tags = services[0]['tags']
      expect(tags).to be_nil
    end

    def check_postgresql(vcap_services, expected_name)
      services = vcap_services['HEROKU_POSTGRESQL_RED_URL']
      expect(services).to have(1).items
      expect(services[0]['name']).to match(expected_name)
      credentials = services[0]['credentials']
      expect(credentials).to have(1).items
      expect(credentials['uri']).to match('postgre://doesnotexist.xyz')
      tags = services[0]['tags']
      expect(tags).to include('postgresql')
    end

    def check_mysql(vcap_services, expected_name)
      services = vcap_services['CLEARDB_DATABASE_URL']
      expect(services).to have(1).items
      expect(services[0]['name']).to match(expected_name)
      credentials = services[0]['credentials']
      expect(credentials).to have(1).items
      expect(credentials['uri']).to match('mysql://ggg:hhh@nnn.com/mmmm')
      tags = services[0]['tags']
      expect(tags).to include('mysql')
    end

    def check_bad(vcap_services, expected_name)
      services = vcap_services['BAD_URL']
      expect(services).to have(1).items
      expect(services[0]['name']).to match(expected_name)
      credentials = services[0]['credentials']
      expect(credentials).to have(2).items
      expect(credentials['uri']).to match('://badurl.xyz')
      expect(credentials['url']).to match('://badurl.xyz')
    end

    def check_mongo(vcap_services, label, expected_name, expected_url)
      services = vcap_services[label]
      expect(services).to have(1).items
      expect(services[0]['name']).to match(expected_name)
      credentials = services[0]['credentials']
      expect(credentials).to have(1).items
      expect(credentials['url']).to match(expected_url)
      tags = services[0]['tags']
      expect(tags).to include('mongodb')
    end

    it 'generate without service mappings' do
      env = {}
      env['DATABASE_URL'] = 'http://u:p@foo:500/bar'
      env['HEROKU_POSTGRESQL_RED_URL'] = 'postgre://doesnotexist.xyz'
      env['CLEARDB_DATABASE_URL'] = 'mysql://ggg:hhh@nnn.com/mmmm'
      env['BAD_URL'] = '://badurl.xyz'
      env['MONGOHQ_URL'] = 'mongodb://myUser:myPassword@myHost.com/myDb'
      env['MONGOLAB_URI'] = 'mongodb://myUser:myPassword@myHost.com:5432/myDb'
      env['MONGOSOUP_URL'] = 'mongodb://myUser:myPassword@myHost1.com,myHost2.com,myHost3.net:5432/myDb'
      vcap_services = Heroku.new.generate_vcap_services(env)

      # verify DATABASE_URL
      check_database_url(vcap_services)

      # verify HEROKU_POSTGRESQL_RED_URL
      check_postgresql(vcap_services, 'postgresql.red')

      # verify CLEARDB_DATABASE_URL
      check_mysql(vcap_services, 'cleardb')

      # verify BAD_URL
      check_bad(vcap_services, 'bad')

      # verify MONGOHQ_URL
      check_mongo(vcap_services, 'MONGOHQ_URL', 'mongohq', env['MONGOHQ_URL'])

      # verify MONGOLAB_URI
      check_mongo(vcap_services, 'MONGOLAB_URI', 'mongolab', env['MONGOLAB_URI'])

      # verify MONGOSOUP_URL
      check_mongo(vcap_services, 'MONGOSOUP_URL', 'mongosoup', env['MONGOSOUP_URL'])
    end

    it 'generate with service mappings' do
      env = {}
      env['DATABASE_URL'] = 'http://u:p@foo:500/bar'
      env['HEROKU_POSTGRESQL_RED_URL'] = 'postgre://doesnotexist.xyz'
      env['CLEARDB_DATABASE_URL'] = 'mysql://ggg:hhh@nnn.com/mmmm'
      env['BAD_URL'] = '://badurl.xyz'
      env['MONGOHQ_URL'] = 'mongodb://myUser:myPassword@myHost.com/myDb'
      env['MONGOLAB_URI'] = 'mongodb://myUser:myPassword@myHost.com:5432/myDb'
      env['MONGOSOUP_URL'] = 'mongodb://myUser:myPassword@myHost1.com,myHost2.com,myHost3.net:5432/myDb'

      m1 = 'HEROKU_POSTGRESQL_RED_URL=myDatabase, CLEARDB_DATABASE_URL = mysqlDb, BAD_URL = myBad'
      m2 = 'MONGOHQ_URL=hq, MONGOLAB_URI=lab, MONGOSOUP_URL=soup'
      env['SERVICE_NAME_MAP'] = m1 + ',' + m2

      vcap_services = Heroku.new.generate_vcap_services(env)

      # verify DATABASE_URL
      check_database_url(vcap_services)

      # verify HEROKU_POSTGRESQL_RED_URL
      check_postgresql(vcap_services, 'myDatabase')

      # verify CLEARDB_DATABASE_URL
      check_mysql(vcap_services, 'mysqlDb')

      # verify BAD_URL
      check_bad(vcap_services, 'myBad')

      # verify MONGOHQ_URL
      check_mongo(vcap_services, 'MONGOHQ_URL', 'hq', env['MONGOHQ_URL'])

      # verify MONGOLAB_URI
      check_mongo(vcap_services, 'MONGOLAB_URI', 'lab', env['MONGOLAB_URI'])

      # verify MONGOSOUP_URL
      check_mongo(vcap_services, 'MONGOSOUP_URL', 'soup', env['MONGOSOUP_URL'])
    end

  end # describe

end # module
