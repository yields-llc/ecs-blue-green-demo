<?php

namespace App\Http\Controllers;

use App\Jobs\Hello;

class Queue extends Controller
{
    public function __invoke()
    {
        $this->dispatch(new Hello());
        return response('App\Job\Hello has been queued.');
    }
}
