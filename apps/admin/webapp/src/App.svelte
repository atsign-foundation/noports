<script>
    // TODO Make the status bar currently in PolicyUserGroups.svelte its own component
    // TODO and allow this page's children to update it

    import logoNoPorts from './assets/noports.jpg';
    import logoAtSign from './assets/atsign.svg';
    import Tabs from './lib/Tabs.svelte';
    import Atsigns from './lib/Atsigns.svelte';
    import Devices from './lib/Devices.svelte';
    import PolicyUserGroups from './lib/PolicyUserGroups.svelte';

    // List of tab items with labels, values and assigned components
    let items = [
        { label: "Devices",
            value: 1,
            component: Devices
        },
        { label: "Atsigns",
            value: 2,
            component: Atsigns
        },
        { label: "Policy",
            value: 3,
            component: PolicyUserGroups
        },
    ];
</script>

<div class="container">
    <h1 style="color: coral"><img src={logoNoPorts} alt="AtSign NoPorts" height="45px"/></h1>

    <hr/>

    <Tabs {items}/>

    <footer class="d-flex flex-wrap justify-content-between align-items-center py-3 my-4 border-top">
        <div class="col-md-4 d-flex align-items-center">
            <span class="mb-3 mb-md-0 text-body-secondary">&copy; 2024&nbsp;&nbsp;</span>
            <img src={logoAtSign} alt="AtSign NoPorts" height="25px"/>
        </div>
    </footer>
</div>
