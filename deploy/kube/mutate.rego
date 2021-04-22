package system

# Entry point to the policy. This is queried by the Kubernetes apiserver.
main = {
    "apiVersion": "admission.k8s.io/v1beta1",
    "kind": "AdmissionReview",
    "response": response,
}

# If no other responses are defined, allow the request.
default response = {
    "allowed": true
}

# Mutate the request if any there are any patches.
response = {
    "allowed": true,
    "patchType": "JSONPatch",
    "patch": base64url.encode(json.marshal(patches)),
} {
    patches := [p | p := patch[_][_]] # iterate over all patches and generate a flattened array
    count(patches) > 0
}

# Note: patch generates a _set_ of arrays. The ordering of the set is not defined.
# If you need to define ordering across patches, generate them inside the same rule.
patch[ops] {
    
    # Only apply mutations to objects in create/update operations (not
    # delete/connect operations.)
    is_create_or_update

    # If the resource has the "test-mutation" annotation key, the patch will be
    # generated and applied to the resource.
    input.request.object.metadata.annotations["http-proxy"]

   	env_vars_to_add := [
    	{"name": "HTTP_PROXY", "value": "http://foo"},
        {"name": "HTTPs_PROXY", "value": "http://bar"},
    ]
    
    ops := get_container_env_patch_ops("/spec/template/spec/containers", input.request.object.spec.template.spec.containers, env_vars_to_add)
}


get_container_env_patch_ops(prefix, containers, env_vars) = result {
   	
    init_env := [op |
    	some i
        containers[i]
        not containers[i].env
        path := sprintf("%v/%d/env", [prefix, i])
    	op := {"op": "add", "path": path, "value": []}
    ]
    
    add_env_vars := [op |
    	some i, j
        containers[i]
        env_vars[j]
        not contains_env_var(containers[i], env_vars[j])
        path := sprintf("%v/%d/env/-", [prefix, i])
        op := {"op": "add", "path": path, "value": env_vars[j]}
    ]

	result := array.concat(init_env, add_env_vars)
}

contains_env_var(container, env_var) {
    container.env[_].name == env_var.name
}

is_create_or_update { is_create }
is_create_or_update { is_update }
is_create { input.request.operation == "CREATE" }
is_update { input.request.operation == "UPDATE" }

# tests for helper function above

test_get_container_env_patch_ops_empty_containers {
    get_container_env_patch_ops("/foo", [], [{"name": "x", "value": "y"}]) == []
}

test_get_container_env_patch_ops_undefined_env_list {
    get_container_env_patch_ops("/foo", [{}], [{"name": "x", "value": "y"}]) == [
        {
            "op": "add",
            "path": "/foo/0/env",
            "value": []
        },
        {
            "op": "add",
            "path": "/foo/0/env/-",
            "value": {
                "name": "x",
                "value": "y"
            }
        }
    ]
}

test_get_container_env_patch_ops_defined_env_list {
    get_container_env_patch_ops("/foo", [{"env": []}], [{"name": "x", "value": "y"}]) == [
        {
            "op": "add",
            "path": "/foo/0/env/-",
            "value": {
                "name": "x",
                "value": "y"
            }
        }
    ]
}

test_get_container_env_patch_ops_multiple_containers {
    get_container_env_patch_ops("/foo", [{"env": []}, {"env": []}], [{"name": "x", "value": "y"}]) == [
        {
            "op": "add",
            "path": "/foo/0/env/-",
            "value": {
                "name": "x",
                "value": "y"
            }
        },
        {
            "op": "add",
            "path": "/foo/1/env/-",
            "value": {
                "name": "x",
                "value": "y"
            }
        }
    ]
}

test_get_container_env_patch_ops_env_var_exists {
    get_container_env_patch_ops("/foo", [{"env": [{"name": "x", "value": "z"}]}], [{"name": "x", "value": "y"}]) == []
}