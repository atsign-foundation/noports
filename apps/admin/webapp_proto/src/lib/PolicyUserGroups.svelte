<script>
    import {onMount} from 'svelte';
    import InPlaceEdit from './InPlaceEdit.svelte'

    let users = [];
    let groups = [];

    let selectedUserIndex = -1;
    let selectedGroupIndex = -1;
    let selectedUserElement;
    let selectedGroupElement;

    let status = '';
    let statusColor = 'green';
    let statusTimeout;

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

    let baseUrl = 'http://localhost:3000/';

    function displayStatus(msg, isError) {
        let t = 1500;
        statusColor='green';
        if (isError) {
            t = 5000;
            statusColor = 'red';
        }
        console.error(msg);
        if (statusTimeout) {
            clearTimeout(statusTimeout);
        }
        status = msg;
        if (msg !== '') {
            statusTimeout = setTimeout(() => {
                status = ''
            }, t)
        }
    }
    async function loadData(url) {
        try {
            const res = await fetch(baseUrl + url);
            const resText = await res.text();
            if (!res.ok) {
                if (resText) {
                    throw new Error(resText);
                } else {
                    throw new Error(`${res.statusText}`);
                }
            }

            console.log(resText);

            let obj = JSON.parse(resText);
            console.log('Length: ', obj.length, 'Values: ', obj.values(), 'Object: ', obj);

            return obj;
        } catch (error) {
            displayStatus(error.message, true);
        }
    }

    function saveGroup(group) {
        displayStatus('Saving group data ... ');
        saveData('group/' + group.name, group);
    }

    function saveUser(user) {
        displayStatus('Saving user data ... ');
        saveData('user/' + user.atSign, user);
    }

    async function saveData(url, obj) {
        try {
            const res = await fetch(baseUrl + 'api/policy/' + url, {
                method: 'POST',
                headers: {
                    Accept: 'application.json',
                    'Content-Type': 'application/json; charset=UTF-8'
                },
                body: JSON.stringify(obj),
                cache: 'default'
            });
            const resText = await res.text();
            if (!res.ok) {
                if (resText) {
                    throw new Error(resText);
                } else {
                    throw new Error(`${res.statusText}`);
                }
            }
        } catch (error) {
            displayStatus(error.message, true);
        }
    }

    async function deleteData(url) {
        try {
            const res = await fetch(baseUrl + 'api/policy/' + url, {
                method: 'DELETE',
                headers: {
                    Accept: 'application.json',
                    'Content-Type': 'application/json; charset=UTF-8'
                },
            });
            const resText = await res.text();
            if (!res.ok) {
                if (resText) {
                    throw new Error(resText);
                } else {
                    throw new Error(`${res.statusText}`);
                }
            }
        } catch (error) {
            displayStatus(error.message, true);
        }
    }

    function deleteUser(user) {
        displayStatus('Removing user ...');
        deleteData('user/' + user.atSign);
    }

    onMount(async () => {
        displayStatus('Loading ...')
        users = await loadData('api/policy/user');
        groups = await loadData('api/policy/group');
        if (status === 'Loading ...') {
            displayStatus('Data loaded');
        }
    });

</script>

<div class="row" style="color: {statusColor}; text-align: center">
    {#if status !== ''}
        <h2>{status}</h2>
    {:else}
        <h2>&nbsp;</h2>

    {/if}
</div>
<div class="row gx-5">
    <div class="col-4">
        <div class="row">
            <div class="border border-primary rounded-3" style="background-color: lightblue">
                <h2>Groups</h2>
                <table class="table">
                    <thead>
                    <tr>
                        <th></th>
                        <th>Name</th>
                        <th>Description</th>
                    </tr>
                    </thead>
                    <tbody>
                    {#each groups as group, i}
                        <tr on:click={(e) => selectGroup(i, e)}>
                            <td>
                                <button type="button" class="btn btn-sm btn-outline-danger">Delete</button>
                            </td>
                            <td>{group.name}</td>
                            <td>{group.description}</td>
                        </tr>
                    {/each}
                    <tr>
                        <td>
                            <button type="button" class="btn btn-sm btn-outline-success">Add group</button>
                        </td>
                        <td></td>
                        <td></td>
                    </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    <div class="col-8">
        <div class="row">
            {#if selectedGroupIndex >= 0 && selectedGroupIndex < groups.length}
                <div class="border border-primary rounded-3" style="background-color:lightblue">
                    <h3>Group: {groups[selectedGroupIndex].name}</h3>
                    <table class="table">
                        <thead>
                        </thead>
                        <tbody>
                        <tr>
                            <td><strong>Description</strong>: {groups[selectedGroupIndex].description}</td>
                        </tr>
                        <tr>
                            <td><strong>Members</strong>: {groups[selectedGroupIndex].userAtSigns}</td>
                        </tr>
                        </tbody>
                    </table>
                    <div class="row">
                        <div class="col-3">
                            <h4>Daemons</h4>
                            <table class="table">
                                <thead>
                                <tr>
                                    <th></th>
                                    <th>atSign</th>
                                </tr>
                                </thead>
                                <tbody>
                                {#each groups[selectedGroupIndex].daemonAtSigns as daemonAtSign}
                                    <tr>
                                        <td>
                                            <button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px">Delete</button>
                                        </td>
                                        <td>{daemonAtSign}</td>
                                    </tr>
                                {/each}
                                <tr>
                                    <td>
                                        <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px">Add</button>
                                    </td>
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
                                    <th></th>
                                    <th>Name</th>
                                    <th>Access</th>
                                </tr>
                                </thead>
                                <tbody>
                                {#each groups[selectedGroupIndex].devices as device}
                                    <tr>
                                        <td>
                                            <button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px">Delete</button>
                                        </td>
                                        <td>
                                            {device.name}
                                        </td>
                                        <td>
                                            <table>
                                                <thead style="display:none"></thead>
                                                <tbody>
                                                {#each device.permitOpens as po, i}
                                                    <tr>
                                                        <td><button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px">-</button></td>
                                                        <td>{po}</td>
                                                    </tr>
                                                {/each}
                                                <tr>
                                                    <td>
                                                        <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px">+</button>
                                                    </td>
                                                </tr>
                                                </tbody>
                                            </table>
                                        </td>
                                    </tr>
                                {/each}
                                <tr>
                                    <td>
                                        <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px">Add</button>
                                    </td>
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
                                    <th></th>
                                    <th>Name</th>
                                    <th>Access</th>
                                </tr>
                                </thead>
                                <tbody>
                                {#each groups[selectedGroupIndex].deviceGroups as dg}
                                    <tr>
                                        <td>
                                            <button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px">Delete</button>
                                        </td>
                                        <td>
                                            {dg.name}
                                        </td>
                                        <td>
                                            <table>
                                                <thead style="display:none; border-width: 0"></thead>
                                                <tbody>
                                                {#each dg.permitOpens as po, i}
                                                    <tr>
                                                        <td><button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px">-</button></td>
                                                        <td>{po}</td>
                                                    </tr>
                                                {/each}
                                                </tbody>
                                                <tr>
                                                    <td>
                                                        <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px">+</button>
                                                    </td>
                                                </tr>
                                            </table>
                                        </td>
                                    </tr>
                                {/each}
                                <tr>
                                    <td>
                                        <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px">Add</button>
                                    </td>
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

<!-- Removing 'Users' functionality as it is unnecessary -->
<!--<div class="row gx-5">-->
<!--    <div class="col-4">-->
<!--        <div class="row">-->
<!--            <div class="border border-primary rounded-3" style="background-color: lightsteelblue">-->
<!--                <h2>Users</h2>-->
<!--                <table class="table">-->
<!--                    <thead>-->
<!--                    <tr>-->
<!--                        <th></th>-->
<!--                        <th>atSign</th>-->
<!--                        <th>Name</th>-->
<!--                    </tr>-->
<!--                    </thead>-->
<!--                    <tbody>-->
<!--                    {#each users as user, i}-->
<!--                        <tr on:click={(e) => selectUser(i, e)}>-->
<!--                            <td>-->
<!--                                <button type="button" class="btn btn-sm btn-outline-danger" on:click={() => deleteUser(user)}>Delete</button>-->
<!--                            </td>-->
<!--                            <td>{user.atSign}</td>-->
<!--                            <td>-->
<!--                                <InPlaceEdit bind:value={user.name} on:submit={() => saveUser(user)}/>-->
<!--                            </td>-->
<!--                        </tr>-->
<!--                    {/each}-->
<!--                    <tr>-->
<!--                        <td>-->
<!--                            <button type="button" class="btn btn-sm btn-outline-success">Add user</button>-->
<!--                        </td>-->
<!--                        <td></td>-->
<!--                        <td></td>-->
<!--                    </tr>-->
<!--                    </tbody>-->
<!--                </table>-->
<!--            </div>-->
<!--        </div>-->
<!--    </div>-->
<!--    <div class="col-3">-->
<!--        <div class="row">-->
<!--            {#if selectedUserIndex >= 0 && selectedUserIndex < users.length}-->
<!--                <div class="border border-primary rounded-3" style="background-color: lightsteelblue">-->
<!--                    <h3>User: {users[selectedUserIndex].name} ({users[selectedUserIndex].atSign})</h3>-->
<!--                    <table class="table">-->
<!--                        <thead>-->
<!--                        <tr>-->
<!--                            <th>Groups</th>-->
<!--                            <th></th>-->
<!--                        </tr>-->
<!--                        </thead>-->
<!--                        <tbody>-->
<!--                        {#each groupsForUser(users[selectedUserIndex]) as group}-->
<!--                            <tr>-->
<!--                                <td>{group.name}</td>-->
<!--                                <td>-->
<!--                                    <button type="button" class="btn btn-sm btn-outline-danger">Remove from group</button>-->
<!--                                </td>-->
<!--                            </tr>-->
<!--                        {/each}-->
<!--                        <tr>-->
<!--                        </tr>-->
<!--                        <tr>-->
<!--                            <td>-->
<!--                                <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px">Add</button>-->
<!--                            </td>-->
<!--                            <td></td>-->
<!--                        </tr>-->
<!--                        </tbody>-->
<!--                    </table>-->
<!--                </div>-->
<!--            {/if}-->
<!--        </div>-->
<!--    </div>-->
<!--</div>-->

