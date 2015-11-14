import React from 'react';
import 'underscore';

class FunItem extends React.Component {
  constructor(props) {
    super(props);
  }

  handleClick(event) {
    this.props.addGraph(this.props.fun)
  }

  render() {
    var fun = this.props.fun;
    return <a href='#' onClick={this.handleClick.bind(this)}
              className='list-group-item'>{fun[0]}:{fun[1]}/{fun[2]}</a>
  }
}

class ACModal extends React.Component {
  constructor(props) {
    super(props);
    this.state = {funs: []};
  }

  displayFuns(data) {
    this.setState({funs: data});
  }

  render() {
    var funs = this.state.funs;
    var rows = [];

    for (let i = 0; i < funs.length && i < 100; i++) {
      rows.push(<FunItem key={funs[i]} addGraph={this.props.addGraph}
                         fun={funs[i]}/>);
    }

    if (funs.length > 0) {
      return (
        <div className="input-group input-group-lg">
          <span style={{opacity:0}} className="input-group-addon"
                id="sizing-addon3">{'>'}</span>
          <div className="panel panel-default">
            <div className="panel-body">
              <div className="list-group">
                {rows}
              </div>
            </div>
          </div>
        </div>)
    } else
    return (<div></div>);
  }
}

export default class FunctionBrowser extends React.Component {

  constructor(props) {
    super(props);
    this.state = {value: ""};
  }

  handleKeyDown(e) {
    var regex = /(\w+):(\w+)\/(\d+)/;
    var res = regex.exec(e.target.value);
    var mod = null, fun = null, arity =null;

    if(res) {
      mod = res[1];
      fun = res[2];
      arity = res[3];
      console.log(e.type);
    }
    if(e.keyCode == 13 && mod != null) {
      this.props.addGraph([mod,fun,parseInt(arity)]);
    }
  }

  handleChange(event) {
    this.setState({value: event.target.value});
    if (event.target.value != "") {
      $.getJSON("/api/funs", {query: event.target.value},
                this.funsSuccess.bind(this));
    }
    else {
      this.refs.acm.displayFuns([]);
    }
  }

  clear() {
    this.refs.acm.displayFuns([]);
    $(React.findDOMNode(this.refs.searchBox)).val("");
  }

  funsSuccess(data) {
    if (this.state.value != "")
      this.refs.acm.displayFuns(data);
  }

  render() {
    var autocomp = null;
    var value = this.state.value;

    return (

      <form className="navbar-form">
        <div className="form-group" style={{display:"inline"}}>
          <div className="input-group" style={{display:"table"}}>
            <span className="input-group-addon" style={{width:"1%"}}><span className="glyphicon glyphicon-search"></span></span>
            <input ref='searchBox' type="text" className="form-control"
                   placeholder="Function" aria-describedby="sizing-addon3"
                   value={value} onKeyDown={this.handleKeyDown.bind(this)}
                   onChange={this.handleChange.bind(this)} autofocus="autofocus"/>

          </div>
        </div>
        <ACModal ref='acm' addGraph={this.props.addGraph}></ACModal>
      </form>

    )
  }
}