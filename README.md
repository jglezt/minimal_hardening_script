# Minimal Hardening Script

Hardening script based on the recommendations given by the [Lynis!](https://cisofy.com/lynis/) security auditing tool.
Most of the recommendations given by the security toll are addressed while adding other ones gathered through the years. The intended use case for this minimal script is for recently installed minimal Centos machines that need to be used through the internet/intranet.

## Usage
The hardening script is almost ready to use, just modify the following elements.

1. Add a message prompt by modifying `./configs/issues.net`.
2. Add as many users in `$MAIN_USERS` variable separated by a space.
3. Change the `$MAIN_GROUP` with the desired group for the main users.
4. Add the respective rsa pub file in `./main_pub/` directory following the next nomenclature
`[user name]-[main group].pub
5. Run and follow the prompt.

## More users
The script can add more users at run time, just type `y` when the prop requires it.

## Sudo access
The script can allow/disallow sudo access to each user individually. By default, the sudo access is password less, but the behavior can be changed by simply modifying the variable `$UNLIMIT_COMMAND_SUDO`.
