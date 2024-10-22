from setuptools import setup, find_packages
def read_requirements():
    with open('requirements.txt', 'r') as file:
        return file.readlines()


setup(
    name='api-warden',
    version='0.1.1',
    packages=find_packages(),
    scripts=['bin/api-warden'], 
    entry_points={
        'console_scripts': [
            'api-warden = warden.cli:main',
        ],
    },
    install_requires=read_requirements(),

)

