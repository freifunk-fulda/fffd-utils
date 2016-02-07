#! /usr/bin/env python3

import argparse
import configparser
import hashlib
import os
import sys
import tempfile

import jinja2
import requests
import requests.auth



class API(object):
    """ This is a (very limited) read-only wrapper for the phpIPAM API.
    """


    def __init__(self,
                 url,
                 app,
                 username,
                 password):

        self.__url = '%s/api/%s' % (url, app)

        # Open session
        self.__session = requests.session()

        # Get authentication token
        authentication = self.__post(('user',),
                                     auth=requests.auth.HTTPBasicAuth(username, password))

        # Use token for every other request
        self.__session.headers['phpipam-token'] = authentication['token']


    def __query(self,
                method,
                endpoint,
                **kwargs):
        # Flatten and stringify the endpoint
        if isinstance(endpoint, (list, tuple)):
            endpoint = '/'.join(str(e) for e in endpoint)

        else:
            endpoint = str(endpoint)

        # Get the executor for the selected method
        executor = getattr(self.__session, method)

        # Execute the request
        response = executor('%s/%s/' % (self.__url, endpoint), **kwargs)

        # Handle errors
        response.raise_for_status()

        # Return the data
        return response.json()['data']


    def __get(self, endpoint, **kwargs):
        return self.__query('get', endpoint, **kwargs)


    def __post(self, endpoint, data=None, **kwargs):
        return self.__query('post', endpoint, data=data, **kwargs)


    def subnets(self,
                network):
        return self.__get(('subnets', 'cidr', network))


    def subnet_addresses(self, subnet_id):
        return self.__get(('subnets', subnet_id, 'addresses'))


    def address(self, address_id):
        return self.__get(('addresses', address_id))



def main():
    argparser = argparse.ArgumentParser("phpIPAM integrator")
    argparser.add_argument('-c', '--config',
                           dest='config',
                           type=argparse.FileType('r', encoding='utf-8'),
                           default='/etc/phpipam-integrator')

    args = argparser.parse_args()

    # Read the configuration file
    config = configparser.ConfigParser()
    config.read_file(args.config)

    # Connect to the API
    api = API(url=config.get(configparser.DEFAULTSECT, 'url'),
              app=config.get(configparser.DEFAULTSECT, 'app'),
              username=config.get(configparser.DEFAULTSECT, 'username'),
              password=config.get(configparser.DEFAULTSECT, 'password'))

    # Collect all triggers for execution
    triggers = set()

    # Handle all defined sections
    for section in config.sections():
        template = config.get(section, 'template')
        output = config.get(section, 'output')
        trigger = config.get(section, 'trigger')

        original_hash = hashlib.sha1()
        modified_hash = hashlib.sha1()

        # Get the hash of the unmodified output
        try:
            with open(output, mode='r', encoding='utf-8') as original:
                for chunk in iter(lambda: original.read(128 * original_hash.block_size), ''):
                    original_hash.update(chunk.encode('utf-8'))

        except FileNotFoundError:
            pass

        # Load the template
        with open(template, mode='r', encoding='utf-8') as f:
            template = jinja2.Template(f.read())

        # Render the template to a temporary file and get the modified hash
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', delete=False) as modified:
            context = {'api': api,
                       'section': section}
            context.update(config.items(section))

            # Render the template in chunks
            stream = template.stream(context)
            stream.enable_buffering()

            # Write the chunk
            for chunk in stream:
                modified.write(chunk)
                modified_hash.update(chunk.encode('utf-8'))

        # Check if the file was changed
        if original_hash.digest() != modified_hash.digest():
            # Copy the temporary to the output file
            os.rename(modified.name, output)

            # Remember trigger for execution
            triggers.add(trigger)

        else:
            # Delete the temporary file
            os.unlink(modified.name)

    # Execute triggers
    for trigger in triggers:
        # Execute the trigger
        os.system(trigger)



if __name__ == '__main__':
    main()

