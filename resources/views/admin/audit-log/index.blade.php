@extends('layouts.admin')

@section('title')
    Audit Log
@endsection

@section('content-header')
    <h1>Audit Log<small>Track all actions performed in the admin panel and through the Application API.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Audit Log</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-xs-12">
        <div class="box box-default">
            <div class="box-header with-border">
                <h3 class="box-title"><i class="fa fa-filter"></i> Filters</h3>
            </div>
            <div class="box-body">
                <form action="{{ route('admin.audit-log') }}" method="GET">
                    <div class="row">
                        <div class="col-sm-4">
                            <div class="form-group">
                                <label>Search</label>
                                <input type="text" name="filter[search]" class="form-control"
                                    placeholder="Username, email, endpoint, IP, API key..."
                                    value="{{ request('filter.search') }}">
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="form-group">
                                <label>Method</label>
                                <select name="filter[method]" class="form-control">
                                    <option value="">All Methods</option>
                                    @foreach(['GET','POST','PATCH','PUT','DELETE'] as $m)
                                        <option value="{{ $m }}" {{ request('filter.method') === $m ? 'selected' : '' }}>{{ $m }}</option>
                                    @endforeach
                                </select>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="form-group">
                                <label>Type</label>
                                <select name="filter[type]" class="form-control">
                                    <option value="">All Types</option>
                                    <option value="admin" {{ request('filter.type') === 'admin' ? 'selected' : '' }}>Admin Panel</option>
                                    <option value="api"   {{ request('filter.type') === 'api'   ? 'selected' : '' }}>API</option>
                                </select>
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="form-group">
                                <label>From Date</label>
                                <input type="date" name="filter[from]" class="form-control" value="{{ request('filter.from') }}">
                            </div>
                        </div>
                        <div class="col-sm-2">
                            <div class="form-group">
                                <label>To Date</label>
                                <input type="date" name="filter[to]" class="form-control" value="{{ request('filter.to') }}">
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-sm-12">
                            <button type="submit" class="btn btn-primary btn-sm"><i class="fa fa-search"></i> Apply Filters</button>
                            <a href="{{ route('admin.audit-log') }}" class="btn btn-default btn-sm"><i class="fa fa-times"></i> Clear</a>
                        </div>
                    </div>
                </form>
            </div>
        </div>

        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">
                    <i class="fa fa-list-alt"></i> Audit Log
                    <span class="label label-default audit-log-count">{{ $logs->total() }} entries</span>
                </h3>
                @if(Auth::user()->root_admin)
                <div class="box-tools pull-right">
                    <form action="{{ route('admin.audit-log.clear') }}" method="POST"
                          onsubmit="return confirm('Are you sure you want to clear ALL audit log entries? This cannot be undone.');">
                        @csrf
                        @method('DELETE')
                        <button type="submit" class="btn btn-danger btn-sm">
                            <i class="fa fa-trash"></i> Clear All
                        </button>
                    </form>
                </div>
                @endif
            </div>
            <div class="box-body table-responsive no-padding">
                <table class="table table-hover table-condensed audit-log-table">
                    <thead>
                        <tr>
                            <th class="col-date">Date &amp; Time</th>
                            <th class="col-user">User</th>
                            <th class="col-method">Method</th>
                            <th class="col-status">Status</th>
                            <th class="col-type">Type</th>
                            <th>Details</th>
                            <th>Endpoint</th>
                            <th class="col-ip">IP Address</th>
                            <th class="col-apikey">API Key</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($logs as $log)
                        <tr>
                            <td>
                                <code class="audit-log-code">{{ $log->created_at->format('Y-m-d H:i:s') }}</code>
                            </td>
                            <td>
                                @if($log->user_id)
                                    <a href="{{ route('admin.users.view', $log->user_id) }}" title="{{ $log->user_email }}">
                                        {{ $log->username ?? $log->user_email ?? 'User #' . $log->user_id }}
                                    </a>
                                @else
                                    <span class="text-muted">Unknown</span>
                                @endif
                            </td>
                            <td>
                                <span class="label {{ $log->action_badge_class }}">{{ $log->action }}</span>
                            </td>
                            <td>
                                @if($log->response_status)
                                    <span class="label {{ $log->status_badge_class }}">{{ $log->response_status }}</span>
                                @else
                                    <span class="text-muted">—</span>
                                @endif
                            </td>
                            <td>
                                @if($log->request_type === 'api')
                                    <span class="label label-default">API</span>
                                @else
                                    <span class="label label-info">Admin</span>
                                @endif
                            </td>
                            <td>
                                @if($log->details)
                                    <span class="audit-log-detail">{{ $log->details }}</span>
                                @else
                                    <span class="text-muted audit-log-na">—</span>
                                @endif
                            </td>
                            <td>
                                <code class="audit-log-code audit-log-endpoint">{{ $log->endpoint }}</code>
                            </td>
                            <td>
                                <code class="audit-log-code">{{ $log->ip_address ?? '—' }}</code>
                            </td>
                            <td>
                                @if($log->api_key_identifier)
                                    <code class="audit-log-code" title="API Key ID: {{ $log->api_key_id }}">
                                        {{ $log->api_key_identifier }}...
                                    </code>
                                @else
                                    <span class="text-muted">—</span>
                                @endif
                            </td>
                        </tr>
                        @empty
                        <tr>
                            <td colspan="9" class="text-center text-muted audit-log-empty">
                                <i class="fa fa-info-circle"></i> No audit log entries found.
                            </td>
                        </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
            @if($logs->hasPages())
            <div class="box-footer with-border">
                <div class="col-md-12 text-center">
                    {!! $logs->appends(request()->query())->render() !!}
                </div>
            </div>
            @endif
        </div>
    </div>
</div>
@endsection
