# mi-core-taiga

This repository is based on [Joyent mibe](https://github.com/joyent/mibe). Please note this repository should be build with the [mi-core-base](https://github.com/skylime/mi-core-base) mibe image.

## description

Image for [Taiga](https://github.com/taigaio/) an agile, free and open source project management tool.

## mdata variables

- `nginx_ssl`: ssl cert, key and CA for nginx in pem format (if not provided Let's Encrypt will be used)

## services

- `80/tcp`: http via nginx
- `443/tcp`: https via nginx
