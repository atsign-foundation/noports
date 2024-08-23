<script>
    import {onMount} from 'svelte';
    import InPlaceEdit from './InPlaceEdit.svelte'

    let users = [];
    let groups = [];

    let selectedUserIndex = -1;
    let selectedGroupIndex = -1;
    let selectedUserElement;
    let selectedGroupElement;

    function selectGroup(ix, event) {
        console.log('group selected: ', groups[ix], 'event', event);
        selectedGroupIndex = ix;
        if (selectedGroupElement != null) {
            selectedGroupElement.classList.remove('selected');
        }
        selectedGroupElement = event.target.parentElement;
        selectedGroupElement.classList.add('selected');
    }

    function selectUser(ix, event) {
        console.log('user selected: ', users[ix], 'event', event);
        selectedUserIndex = ix;
        if (selectedUserElement != null) {
            selectedUserElement.classList.remove('selected');
        }
        selectedUserElement = event.target.parentElement;
        selectedUserElement.classList.add('selected');
    }

    function groupsForUser(user) {
        let g = [];
        for (let i = 0; i < groups.length; i++) {
            if (groups[i].userAtSigns.indexOf(user.atSign) >= 0) {
                g.push(groups[i]);
            }
        }
        return g;
    }

    function submit(object, field) {
        return ({detail: newValue}) => {
            // IRL: POST value to server here
            console.log(`updated ${object}, new value for ${field} is: "${newValue}"`)
            // object[field] = newValue;
            // object = object;
            // users = users;
            // groups = groups;
        }
    }
    async function loadData(url) {
        try {
            const res = await fetch(url);
            if (!res.ok) {
                throw new Error(`Response status: ${res.status}`);
            }

            const json = await res.text();
            console.log(json);

            let obj = JSON.parse(json);
            console.log('Length: ', obj.length, 'Values: ', obj.values(), 'Object: ', obj);

            return obj;
        } catch (error) {
            console.error(error.message);
        }
    }

    onMount(async () => {
        users = await loadData('http://localhost:3000/api/policy/user');
        groups = await loadData('http://localhost:3000/api/policy/group');
    });
</script>

<div class="row gx-5">
    <div class="col-5">
        <div class="row">
            <div class="border border-primary rounded-3" style="background-color: lightblue">
                <h2>Groups</h2>
                <table class="table">
                    <thead>
                    <tr>
                        <th>Name</th>
                        <th>Description</th>
                        <th></th>
                    </tr>
                    </thead>
                    <tbody>
                    {#each groups as group, i}
                        <tr on:click={(e) => selectGroup(i, e)}>
                            <td>{group.name}</td>
                            <td>{group.description}</td>
                            <td><button type="button" class="btn btn-sm btn-outline-danger">Delete</button></td>
                        </tr>
                    {/each}
                    <tr>
                        <td><button type="button" class="btn btn-sm btn-outline-success">Add group</button></td>
                        <td></td>
                        <td></td>
                    </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    <div class="col-7">
        <div class="row">
            {#if selectedGroupIndex >= 0 && selectedGroupIndex < groups.length}
                <div class="border border-primary rounded-3" style="background-color:lightblue">
                    <h3>Group: {groups[selectedGroupIndex].name}</h3>
                    <table class="table">
                        <thead>
                        </thead>
                        <tbody>
                        <tr>
                            <td>Detail: {groups[selectedGroupIndex].description}</td>
                        </tr>
                        <tr>
                            <td>Members: {groups[selectedGroupIndex].userAtSigns}</td>
                        </tr>
                        </tbody>
                    </table>
                    <div class="row">
                        <div class="col-3">
                            <h4>Daemons</h4>
                            <table class="table">
                                <thead>
                                <tr>
                                    <th>atSign</th>
                                    <th></th>
                                </tr>
                                </thead>
                                <tbody>
                                {#each groups[selectedGroupIndex].daemonAtSigns as daemonAtSign}
                                    <tr>
                                        <td>{daemonAtSign}</td>
                                        <td><button type="button" class="btn btn-sm btn-outline-danger">Delete</button></td>
                                    </tr>
                                {/each}
                                <tr>
                                    <td><button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px">+</button></td>
                                    <td></td>
                                </tr>
                                </tbody>
                            </table>
                        </div>
                        <div class="col">
                            <h4>Devices</h4>
                            <table class="table">
                                <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Access</th>
                                    <th></th>
                                </tr>
                                </thead>
                                <tbody>
                                {#each groups[selectedGroupIndex].devices as device}
                                    {#each device.permitOpens as po, i}
                                        <tr>
                                            <td>
                                                {#if i == 0}{device.name}{/if}
                                            </td>
                                            <td>{po}</td>
                                            <td><button type="button" class="btn btn-sm btn-outline-danger">Delete</button></td>
                                        </tr>
                                    {/each}
                                {/each}
                                <tr>
                                    <td><button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px">+</button></td>
                                    <td></td>
                                    <td></td>
                                </tr>
                                </tbody>
                            </table>
                        </div>
                        <div class="col">
                            <h4>Device Groups</h4>
                            <table class="table">
                                <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Access</th>
                                    <th></th>
                                </tr>
                                </thead>
                                <tbody>
                                {#each groups[selectedGroupIndex].deviceGroups as dg}
                                    {#each dg.permitOpens as po, i}
                                        <tr>
                                            <td>
                                                {#if i == 0}{dg.name}{/if}
                                            </td>
                                            <td>{po}</td>
                                            <td><button type="button" class="btn btn-sm btn-outline-danger">Delete</button></td>
                                        </tr>
                                    {/each}
                                {/each}
                                <tr>
                                    <td><button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px">+</button></td>
                                    <td></td>
                                    <td></td>
                                </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            {/if}
        </div>
    </div>
</div>

<hr/>

<div class="row gx-5">
    <div class="col-5">
        <div class="row">
            <div class="border border-primary rounded-3" style="background-color: lightsteelblue">
                <h2>Users</h2>
                <table class="table">
                    <thead>
                    <tr>
                        <th>atSign</th>
                        <th>Name</th>
                        <th></th>
                    </tr>
                    </thead>
                    <tbody>
                    {#each users as user, i}
                        <tr on:click={(e) => selectUser(i, e)}>
                            <td>{user.atSign}</td>
                            <td>
                                <InPlaceEdit bind:value={user.name} on:submit={() => submit(user, 'name')}/>
                            </td>
                            <td><button type="button" class="btn btn-sm btn-outline-danger">Delete</button></td>
                        </tr>
                    {/each}
                    <tr>
                        <td><button type="button" class="btn btn-sm btn-outline-success">Add user</button></td>
                        <td></td>
                        <td></td>
                    </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    <div class="col-5">
        <div class="row">
            {#if selectedUserIndex >= 0 && selectedUserIndex < users.length}
                <div class="border border-primary rounded-3" style="background-color: lightsteelblue">
                    <h3>User: {users[selectedUserIndex].name} ({users[selectedUserIndex].atSign})</h3>
                    <table class="table">
                        <thead>
                        <tr>
                            <th>Groups</th>
                            <th></th>
                        </tr>
                        </thead>
                        <tbody>
                        {#each groupsForUser(users[selectedUserIndex]) as group}
                            <tr>
                                <td>{group.name}</td>
                                <td><button type="button" class="btn btn-sm btn-outline-danger">Remove from group</button></td>
                            </tr>
                        {/each}
                        <tr>
                        </tr>
                        <tr>
                            <td><button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px">+</button></td>
                            <td></td>
                        </tr>
                        </tbody>
                    </table>
                </div>
            {/if}
        </div>
    </div>
</div>

