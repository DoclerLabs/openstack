#!/usr/bin/python
# -*- coding: utf-8 -*-

# Based on Jimmy Tang's implementation

DOCUMENTATION = '''
---
module: keystone_user
version_added: "1.2"
short_description: Manage OpenStack Identity (keystone) users, projects and roles
description:
   - Manage users,projects, roles from OpenStack.
options:
   login_user:
     description:
        - login username to authenticate to keystone
     required: false
     default: admin
   login_password:
     description:
        - Password of login user
     required: false
     default: 'yes'
   login_project_name:
     description:
        - The project login_user belongs to
     required: false
     default: None
     version_added: "1.3"
   token:
     description:
        - The token to be uses in case the password is not specified
     required: false
     default: None
   endpoint:
     description:
        - The keystone url for authentication
     required: false
     default: 'http://127.0.0.1:35357/v2.0/'
   user:
     description:
        - The name of the user that has to added/removed from OpenStack
     required: false
     default: None
   password:
     description:
        - The password to be assigned to the user
     required: false
     default: None
   project:
     description:
        - The project name that has be added/removed
     required: false
     default: None
   project_description:
     description:
        - A description for the project
     required: false
     default: None
   email:
     description:
        - An email address for the user
     required: false
     default: None
   domain:
     description:
        - The domain for the user
     required: false
     default: default
   role:
     description:
        - The name of the role to be assigned or created
     required: false
     default: None
   state:
     description:
        - Indicate desired state of the resource
     choices: ['present', 'absent']
     default: present
requirements: [ python-keystoneclient ]
author: Lorin Hochstein
'''

EXAMPLES = '''
# Create a project
- keystone_user: project=demo project_description="Default project"

# Create a user
- keystone_user: user=john project=demo password=secrete

# Apply the admin role to the john user in the demo project
- keystone_user: role=admin user=john project=demo
'''

try:
    from keystoneclient.v3 import client
except ImportError:
    keystoneclient_found = False
else:
    keystoneclient_found = True


def authenticate(endpoint, token, login_user, login_password, login_project_name):
    """Return a keystone client object"""

    if token:
        return client.Client(endpoint=endpoint, token=token)
    else:
        return client.Client(auth_url=endpoint, username=login_user,
                             password=login_password, project_name=login_project_name)

def project_exists(keystone, project):
    """ Return True if project already exists"""
    return project in [x.name for x in keystone.projects.list()]


def user_exists(keystone, user):
    """" Return True if user already exists"""
    return user in [x.name for x in keystone.users.list()]


def get_project(keystone, name):
    """ Retrieve a project by name"""
    projects = [x for x in keystone.projects.list() if x.name == name]
    count = len(projects)
    if count == 0:
        raise KeyError("No keystone projects with name %s" % name)
    elif count > 1:
        raise ValueError("%d projects with name %s" % (count, name))
    else:
        return projects[0]


def get_user(keystone, name):
    """ Retrieve a user by name"""
    users = [x for x in keystone.users.list() if x.name == name]
    count = len(users)
    if count == 0:
        raise KeyError("No keystone users with name %s" % name)
    elif count > 1:
        raise ValueError("%d users with name %s" % (count, name))
    else:
        return users[0]


def get_role(keystone, name):
    """ Retrieve a role by name"""
    roles = [x for x in keystone.roles.list() if x.name == name]
    count = len(roles)
    if count == 0:
        raise KeyError("No keystone roles with name %s" % name)
    elif count > 1:
        raise ValueError("%d roles with name %s" % (count, name))
    else:
        return roles[0]


def get_project_id(keystone, name):
    return get_project(keystone, name).id


def get_user_id(keystone, name):
    return get_user(keystone, name).id


def ensure_project_exists(keystone, project_name, project_description, project_domain,
                         check_mode):
    """ Ensure that a project exists.

        Return (True, id) if a new project was created, (False, None) if it
        already existed.
    """

    # Check if project already exists
    try:
        project = get_project(keystone, project_name)
    except KeyError:
        # project doesn't exist yet
        pass
    else:
        if project.description == project_description:
            return (False, project.id)
        else:
            # We need to update the project description
            if check_mode:
                return (True, project.id)
            else:
                project.update(description=project_description)
                return (True, project.id)

    # We now know we will have to create a new project
    if check_mode:
        return (True, None)

    ks_project = keystone.projects.create(name=project_name,
                                        description=project_description,
                                        domain=project_domain,
                                        enabled=True)
    return (True, ks_project.id)


def ensure_project_absent(keystone, project, check_mode):
    """ Ensure that a project does not exist

         Return True if the project was removed, False if it didn't exist
         in the first place
    """
    if not project_exists(keystone, project):
        return False

    # We now know we will have to delete the project
    if check_mode:
        return True


def ensure_user_exists(keystone, user_name, password, email, domain, project_name,
                       check_mode):
    """ Check if user exists

        Return (True, id) if a new user was created, (False, id) user alrady
        exists
    """

    # Check if project already exists
    try:
        user = get_user(keystone, user_name)
    except KeyError:
        # project doesn't exist yet
        pass
    else:
        # User does exist, we're done
        return (False, user.id)

    # We now know we will have to create a new user
    if check_mode:
        return (True, None)
    project = get_project(keystone, project_name)

    user = keystone.users.create(name=user_name, password=password,
                                 email=email, domain=domain, default_project=project.id)

    return (True, user.id)


def ensure_role_exists(keystone, user_name, project_name, role_name,
                       check_mode):
    """ Check if role exists

        Return (True, id) if a new role was created or if the role was newly
        assigned to the user for the project. (False, id) if the role already
        exists and was already assigned to the user ofr the project.

    """
    # Check if the user has the role in the project
    user = get_user(keystone, user_name)
    project = get_project(keystone, project_name)
    roles = [x for x in keystone.roles.list(user=user, project=project)
                     if x.name == role_name]
    count = len(roles)

    if count == 1:
        # If the role is in there, we are done
        role = roles[0]
        return (False, role.id)
    elif count > 1:
        # Too many roles with the same name, throw an error
        raise ValueError("%d roles with name %s" % (count, role_name))

    # At this point, we know we will need to make changes
    if check_mode:
        return (True, None)

    # Get the role if it exists
    try:
        role = get_role(keystone, role_name)
    except KeyError:
        # Role doesn't exist yet
        role = keystone.roles.create(role_name)

    # Associate the role with the user in the admin
    keystone.roles.grant(user=user, role=role, project=project)
    return (True, role.id)


def ensure_user_absent(keystone, user, check_mode):
    raise NotImplementedError("Not yet implemented")


def ensure_role_absent(keystone, uesr, project, role, check_mode):
    raise NotImplementedError("Not yet implemented")


def main():

    argument_spec = openstack_argument_spec()
    argument_spec.update(dict(
            project_description=dict(required=False),
            email=dict(required=False),
            domain=dict(required=False, default="default"),
            user=dict(required=False),
            project=dict(required=False),
            password=dict(required=False),
            role=dict(required=False),
            state=dict(default='present', choices=['present', 'absent']),
            endpoint=dict(required=False,
                          default="http://127.0.0.1:35357/v2.0"),
            token=dict(required=False),
            login_user=dict(required=False),
            login_password=dict(required=False),
            login_project_name=dict(required=False)
    ))
    # keystone operations themselves take an endpoint, not a keystone auth_url
    del(argument_spec['auth_url'])
    module = AnsibleModule(
        argument_spec=argument_spec,
        supports_check_mode=True,
        mutually_exclusive=[['token', 'login_user'],
                            ['token', 'login_password'],
                            ['token', 'login_project_name']]
    )

    if not keystoneclient_found:
        module.fail_json(msg="the python-keystoneclient module is required")

    user = module.params['user']
    password = module.params['password']
    project = module.params['project']
    project_description = module.params['project_description']
    email = module.params['email']
    domain = module.params['domain']
    role = module.params['role']
    state = module.params['state']
    endpoint = module.params['endpoint']
    token = module.params['token']
    login_user = module.params['login_user']
    login_password = module.params['login_password']
    login_project_name = module.params['login_project_name']

    keystone = authenticate(endpoint, token, login_user, login_password, login_project_name)

    check_mode = module.check_mode

    try:
        d = dispatch(keystone, user, password, project, project_description,
                     email, domain, role, state, endpoint, token, login_user,
                     login_password, check_mode)
    except Exception, e:
        if check_mode:
            # If we have a failure in check mode
            module.exit_json(changed=True,
                             msg="exception: %s" % e)
        else:
            module.fail_json(msg="exception: %s" % e)
    else:
        module.exit_json(**d)


def dispatch(keystone, user=None, password=None, project=None,
             project_description=None, email=None, domain=None, role=None,
             state="present", endpoint=None, token=None, login_user=None,
             login_password=None, check_mode=False):
    """ Dispatch to the appropriate method.

        Returns a dict that will be passed to exit_json

        project  user  role   state
        ------  ----  ----  --------
          X                  present     ensure_project_exists
          X                  absent      ensure_project_absent
          X      X           present     ensure_user_exists
          X      X           absent      ensure_user_absent
          X      X     X     present     ensure_role_exists
          X      X     X     absent      ensure_role_absent


        """
    changed = False
    id = None
    if project and not user and not role and state == "present":
        changed, id = ensure_project_exists(keystone, project,
                                           project_description, domain, check_mode)
    elif project and not user and not role and state == "absent":
        changed = ensure_project_absent(keystone, project, check_mode)
    elif project and user and not role and state == "present":
        changed, id = ensure_user_exists(keystone, user, password,
                                         email, domain, project, check_mode)
    elif project and user and not role and state == "absent":
        changed = ensure_user_absent(keystone, user, check_mode)
    elif project and user and role and state == "present":
        changed, id = ensure_role_exists(keystone, user, project, role,
                                         check_mode)
    elif project and user and role and state == "absent":
        changed = ensure_role_absent(keystone, user, project, role, check_mode)
    else:
        # Should never reach here
        raise ValueError("Code should never reach here")

    return dict(changed=changed, id=id)

# import module snippets
from ansible.module_utils.basic import *
from ansible.module_utils.openstack import *
if __name__ == '__main__':
    main()
