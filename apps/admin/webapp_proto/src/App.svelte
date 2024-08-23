<script>
    import PolicyUserGroups from './lib/PolicyUserGroups.svelte';
    import Child from './lib/Child.svelte';
    let value=1;
    let depth=1;
</script>

<div class="container">
    <h1 style="color: darkorange">NoPorts Policy Manager</h1>

    <hr/>

<!--    <PolicyUserGroups />-->
    <div>Parent: Value is {value} Depth is {depth}</div>
    <div>
        <Child value={value} depth={depth}></Child>
    </div>
</div>
