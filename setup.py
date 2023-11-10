def read_requirements():
    with open('requirements.txt', 'r') as file:
        return file.readlines()

from setuptools import setup, find_packages

setup(
    name='api-warden',
    version='0.1.1',
    packages=find_packages(),
    scripts=['bin/api-warden'], 
    entry_points={
        'console_scripts': [
            'api-warden = cli:main',
        ],
    },
    install_requires=read_requirements(),

)

